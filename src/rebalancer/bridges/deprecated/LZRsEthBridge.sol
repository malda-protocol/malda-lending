// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {
    ILayerZeroOFT,
    SendParam,
    MessagingFee,
    ILayerZeroOFTWrapper
} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

import {IBridge} from "src/interfaces/IBridge.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {SafeApprove} from "src/libraries/SafeApprove.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

interface ILayerZeroComposer {
    function lzCompose(
        address from,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) external payable;
}

contract LZRsEthBridge is BaseBridge, IBridge, ILayerZeroComposer {
    using SafeERC20 for IERC20;

    // TODO: implement this becase rSETH for example is:
    //  oft on linea
    // wrapper on returns
    // weETH is oft on chain A and adapter on rest
    enum OFTType {
        OFT,
        Adapter,
        Wrapper
    }

    // ----------- STORAGE ------------
    /// underlying (legacy) => bridge contract (OFT or adapter) ON THIS CHAIN
    mapping(address => address) public bridgeContracts;

    /// LayerZero Endpoint on THIS chain (for compose auth)
    address public immutable endpoint;

    // ----------- EVENTS ------------
    event MsgSent(uint32 indexed dstChainId, address indexed market, uint256 amountLD, uint256 minAmountLD, bytes32 guid);
    event BridgeContractSet(address indexed underlying, address indexed bridgeContract);

    // ----------- ERRORS ------------
    error LZBridge_NotEnoughFees();
    error LZBridge_ChainNotRegistered();
    error LZBridge_DestinationMismatch();
    error LZBridge_DifferentInnerToken();
    error LZBridge_NoOft();
    error LZBridge_TokenMismatch();
    error LZBridge_AmountMismatch();
    error LZBridge_NoOFTMinted();
    error LZBridge_OnlyEndpoint();
    error LZBridge_BadFrom();
    error LZBridge_NoRemote();

    constructor(address _roles, address _endpoint) BaseBridge(_roles) {
        require(_endpoint != address(0), "endpoint=0");
        endpoint = _endpoint;
    }

    // ----------- ADMIN ------------
    function setBridgeContract(address underlying, address bridgeContract) external onlyBridgeConfigurator {
        bridgeContracts[underlying] = bridgeContract;
        emit BridgeContractSet(underlying, bridgeContract);
    }

    // ----------- VIEW ------------
    function getFee(uint32 _dstChainId, bytes memory _message, bytes memory)
        external
        view
        returns (uint256)
    {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());
        (MessagingFee memory fees,) = _quote(_dstChainId, _message);
        return fees.nativeFee;
    }

    // ----------- EXTERNAL ------------
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes memory _message,
        bytes memory
    )
        external
        payable
        onlyRebalancer
    {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());

        (address market,,,) = abi.decode(_message, (address, uint256, uint256, bytes));
        require(_market == market, LZBridge_DestinationMismatch());

        (MessagingFee memory fees, SendParam memory sendParam) = _quote(_dstChainId, _message);
        if (msg.value < fees.nativeFee) revert LZBridge_NotEnoughFees();
        require(_extractedAmount == sendParam.amountLD, BaseBridge_AmountMismatch());

        address underlying = ImTokenMinimal(_market).underlying();
        if (underlying != _token) revert LZBridge_TokenMismatch();

        address bridgeContract = bridgeContracts[underlying];
        if (bridgeContract == address(0)) bridgeContract = underlying;

        // pull from rebalancer
        IERC20(_token).safeTransferFrom(msg.sender, address(this), sendParam.amountLD);

        // adapter path: deposit legacy -> mint OFT to this contract (on source)
        if (bridgeContract != underlying) {
            try ILayerZeroOFTWrapper(underlying).allowedTokens(bridgeContract) returns (bool ok) {
                require(ok, LZBridge_DifferentInnerToken());
            } catch {
                revert LZBridge_NoOft();
            }
            SafeApprove.safeApprove(underlying, bridgeContract, sendParam.amountLD);
            ILayerZeroOFTWrapper(underlying).withdraw(bridgeContract, sendParam.amountLD);

            if (IERC20(bridgeContract).balanceOf(address(this)) < sendParam.amountLD) {
                revert LZBridge_AmountMismatch();
            }
        }

        // send OFT to destination bridge; compose will withdraw -> legacy -> market
        (MessagingReceipt memory msgReceipt,) =
            ILayerZeroOFT(bridgeContract).send{value: fees.nativeFee}(sendParam, fees, msg.sender);

        emit MsgSent(_dstChainId, market, sendParam.amountLD, sendParam.minAmountLD, msgReceipt.guid);
    }

    // @dev fallback route in case `lzCompose` is not working
    function processUncomposedMessages(address _market) external payable onlyBridgeConfigurator {
        address underlying = ImTokenMinimal(_market).underlying();
        address bridgeContract = bridgeContracts[underlying];
        uint256 balance;
        if (bridgeContract == address(0)) {
            balance = IERC20(underlying).balanceOf(address(this));
            // just transfer underlying to market
            IERC20(underlying).safeTransfer(_market, balance);
        } else {
            // .withdraw on bridge contract
            balance = IERC20(underlying).balanceOf(address(this));
            ILayerZeroOFTWrapper(bridgeContract).deposit(underlying, balance);
        }
    }

    // ----------- DESTINATION COMPOSE ------------
    function lzCompose(
        address from,
        bytes32 /*guid*/,
        bytes calldata message,
        address /*executor*/,
        bytes calldata /*extraData*/
    ) external payable override {
        if (msg.sender != endpoint) revert LZBridge_OnlyEndpoint();

        (address market) = abi.decode(message, (address));
        address underlying = ImTokenMinimal(market).underlying();

        // Resolve the OFT/OFTAdapter configured for this underlying on THIS chain
        address oftWrapper = bridgeContracts[underlying];
        if (oftWrapper == address(0)) oftWrapper = underlying;

        // Ensure compose came from that OFT (destination side)
        if (from != oftWrapper) revert LZBridge_BadFrom();

        uint256 amt = IERC20(oftWrapper).balanceOf(address(this));
        if (amt == 0) revert LZBridge_NoOFTMinted();

        ILayerZeroOFTWrapper(oftWrapper).deposit(underlying, amt);
    }

    // ----------- PRIVATE ------------
    function _quote(uint32 dstEid, bytes memory _message)
        private
        view
        returns (MessagingFee memory fees, SendParam memory lzSendParams)
    {
        (address market, uint256 amountLD, uint256 minAmountLD, bytes memory extraOptions) =
            abi.decode(_message, (address, uint256, uint256, bytes));

        address underlying = ImTokenMinimal(market).underlying();
        address bridgeContract = bridgeContracts[underlying];
        if (bridgeContract == address(0)) bridgeContract = underlying;

        lzSendParams = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(market))), 
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: extraOptions,               
            composeMsg: bytes(""),
            oftCmd: ""
        });

        fees = ILayerZeroOFT(bridgeContract).quoteSend(lzSendParams, false);
    }
}
