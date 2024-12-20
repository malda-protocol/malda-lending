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

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

contract LZBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    //TODO: refactor to maybe use uint32 directly?!; check when everything else is implemented
    mapping(uint256 dstChainId => uint32 eId) public chainToEid;

    // ----------- EVENTS ------------
    event ChainIdSet(uint256 indexed chainId, uint256 indexed eId);
    event MsgSent(
        uint256 indexed dstChainId, address indexed market, uint256 amountLD, uint256 minAmountLD, bytes32 guid
    );

    error LZBridge_NotEnoughFees();
    error LZBridge_NotAuthorized();
    error LZBridge_ChainNotRegistered();

    constructor(address _roles) BaseBridge(_roles) {}

    // ----------- OWNER ------------
    /**
     * @notice updates cross chain peer
     * @param _chainId the block.chain id
     * @param _eId the LZ endpoint id
     */
    function updateChainToEid(uint256 _chainId, uint32 _eId) external onlyBridgeConfigurator {
        chainToEid[_chainId] = _eId;
        emit ChainIdSet(_chainId, _eId);
    }

    // ----------- VIEW ------------
    /**
     * @inheritdoc IBridge
     * @dev use `getOptionsData` for `_bridgeData`
     */
    function getFee(uint256 _dstChainId, bytes memory _message, bytes memory _composeMsg)
        external
        view
        returns (uint256)
    {
        uint32 dstEid = chainToEid[_dstChainId];
        require(dstEid > 0, LZBridge_ChainNotRegistered());

        (MessagingFee memory fees,) = _getFee(dstEid, _message, _composeMsg);
        return fees.nativeFee; // no option to pay in LZ token with this version
    }

    // ----------- EXTERNAL ------------
    /**
     * @inheritdoc IBridge
     */
    function sendMsg(uint256 _dstChainId, address _token, bytes memory _message, bytes memory _composeMsg)
        external
        payable
        onlyRebalancer
    {
        // get destination
        uint32 dstEid = chainToEid[_dstChainId];
        require(dstEid > 0, LZBridge_ChainNotRegistered());

        // get market
        (address market,,,) = abi.decode(_message, (address, uint256, uint256, bytes));

        // compute fee and craft message
        (MessagingFee memory fees, SendParam memory sendParam) = _getFee(dstEid, _message, _composeMsg);
        if (msg.value < fees.nativeFee) revert LZBridge_NotEnoughFees();
        require(sendParam.amountLD >= minTransfer && sendParam.amountLD <= maxTransfer, BaseBridge_AmountNotValid());

        // retrieve tokens from `Rebalancer`
        IERC20(_token).safeTransferFrom(msg.sender, address(this), sendParam.amountLD);

        //TODO: add result guid to event
        // send OFT
        (MessagingReceipt memory msgReceipt,) = ILayerZeroOFT(_token).send{value: msg.value}(sendParam, fees, market); // refundAddress = market

        emit MsgSent(_dstChainId, market, sendParam.amountLD, sendParam.minAmountLD, msgReceipt.guid);
    }

    // ----------- PRIVATE ------------
    function _getFee(uint32 dstEid, bytes memory _message, bytes memory _composeMsg)
        private
        view
        returns (MessagingFee memory fees, SendParam memory lzSendParams)
    {
        (address market, uint256 amountLD, uint256 minAmountLD, bytes memory extraOptions) =
            abi.decode(_message, (address, uint256, uint256, bytes));
        lzSendParams = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(market))), // deployed with CREATE3
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: extraOptions,
            composeMsg: _composeMsg,
            oftCmd: ""
        });
        address _underlying = ImTokenMinimal(market).underlying();

        fees = ILayerZeroOFT(_underlying).quoteSend(lzSendParams, false);
    }
}
