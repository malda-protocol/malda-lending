// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {ILayerZeroOFT, SendParam, MessagingFee} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

import {IBridge} from "src/interfaces/IBridge.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {SafeApprove} from "src/libraries/SafeApprove.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

contract LZUnifiedBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    /// @notice underlying token => bridge contract (OFT or adapter)
    mapping(address => address) public bridgeContracts;

    // ----------- EVENTS ------------
    event MsgSent(
        uint32 indexed dstChainId, address indexed market, uint256 amountLD, uint256 minAmountLD, bytes32 guid
    );

    event BridgeContractSet(address indexed underlying, address indexed bridgeContract);

    error LZBridge_NotEnoughFees();
    error LZBridge_ChainNotRegistered();
    error LZBridge_DestinationMismatch();
    error LZBridge_DifferentInnerToken();
    error LZBridge_NoOft();

    constructor(address _roles) BaseBridge(_roles) {}

    function setBridgeContract(address underlying, address bridgeContract) external onlyBridgeConfigurator {
        bridgeContracts[underlying] = bridgeContract;
        emit BridgeContractSet(underlying, bridgeContract);
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc IBridge
     * @dev use `getOptionsData` for `_bridgeData`
     */
    function getFee(uint32 _dstChainId, bytes memory _message, bytes memory)
        external
        view
        returns (uint256)
    {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());

        (MessagingFee memory fees,) = _getFee(_dstChainId, _message);
        return fees.nativeFee; // no option to pay in LZ token with this version
    }

    // ----------- EXTERNAL ------------
    /**
     * @inheritdoc IBridge
     */
    function sendMsg(uint256 _extractedAmount, address _market, uint32 _dstChainId, address _token, bytes memory _message, bytes memory)
        external
        payable
        onlyRebalancer
    {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());

        // get market
        (address market,,,) = abi.decode(_message, (address, uint256, uint256, bytes));
        require (_market == market, LZBridge_DestinationMismatch());

        // compute fee and craft message
        (MessagingFee memory fees, SendParam memory sendParam) = _getFee(_dstChainId, _message);
        if (msg.value < fees.nativeFee) revert LZBridge_NotEnoughFees();
        require(_extractedAmount == sendParam.amountLD, BaseBridge_AmountMismatch());

        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), sendParam.amountLD);

        address _underlying = ImTokenMinimal(_market).underlying();
        address _bridgeContract = bridgeContracts[_underlying];
        if (_bridgeContract == address(0)) {
            _bridgeContract = _underlying;
        }

        if (_bridgeContract != _underlying) {
            // it means we need an OFTAdapter
            try ILayerZeroOFT(_bridgeContract).token() returns (address inner) {
                require(inner == _underlying, LZBridge_DifferentInnerToken());
            } catch {
                revert LZBridge_NoOft();
            }
            SafeApprove.safeApprove(_underlying, _bridgeContract, sendParam.amountLD);
        }

        // send OFT
        (MessagingReceipt memory msgReceipt,) = ILayerZeroOFT(_bridgeContract).send{value: fees.nativeFee}(sendParam, fees, msg.sender); // fee refund = rebalancer

        emit MsgSent(_dstChainId, market, sendParam.amountLD, sendParam.minAmountLD, msgReceipt.guid);
    }

    // ----------- PRIVATE ------------
    function _getFee(uint32 dstEid, bytes memory _message)
        private
        view
        returns (MessagingFee memory fees, SendParam memory lzSendParams)
    {
        (address market, uint256 amountLD, uint256 minAmountLD, bytes memory extraOptions) =
            abi.decode(_message, (address, uint256, uint256, bytes));

        address _underlying = ImTokenMinimal(market).underlying();
        address _bridgeContract = bridgeContracts[_underlying];
        if (_bridgeContract == address(0)) {
            _bridgeContract = _underlying;
        }

        lzSendParams = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(market))), // deployed with CREATE3
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: extraOptions,
            composeMsg: "",
            oftCmd: ""
        });
        fees = ILayerZeroOFT(_bridgeContract).quoteSend(lzSendParams, false);
    }
}