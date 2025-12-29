// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {ILayerZeroOFT, SendParam, MessagingFee} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

import {IBridge} from "src/interfaces/IBridge.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IOftMessageExecutor} from "src/interfaces/IOftMessageExecutor.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";

/// @title LZUnifiedBridge
/// @author Malda Protocol
/// @notice LayerZero v2 unified bridge used by the Rebalancer to send assets cross-chain via OFT-compatible tokens.
contract LZUnifiedBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;

    /// @notice Local vars used to avoid stack-too-deep in sendMsg().
    struct SendMsgLocalVars {
        address market;
        address underlying;
        address bridgeContract;
        MessagingFee fees;
        SendParam sendParam;
    }

    /// @notice LayerZero endpoint contract allowed to call lzCompose().
    address public immutable ENDPOINT;

    /// @notice Maps underlying token => bridge contract (OFT). If not set, defaults to underlying itself.
    mapping(address underlying => address bridgeContract) public bridgeContracts;

    /// @notice Maps underlying token => executor contract used via delegatecall for send/compose flows.
    mapping(address underlying => address executor) public oftExecutors;

    /// @notice Emitted after a message is sent via LayerZero.
    /// @param dstChainId Destination chain id (eid).
    /// @param market Market address encoded in compose payload.
    /// @param amountLD Amount sent (local decimals).
    /// @param minAmountLD Minimum amount expected on destination (local decimals).
    /// @param guid LayerZero message GUID.
    event MsgSent(
        uint32 indexed dstChainId, address indexed market, uint256 amountLD, uint256 minAmountLD, bytes32 guid
    );

    /// @notice Emitted when a bridge contract is configured for an underlying.
    /// @param underlying Underlying token address.
    /// @param bridgeContract Bridge contract (OFT) used for that underlying.
    event BridgeContractSet(address indexed underlying, address indexed bridgeContract);

    /// @notice Emitted when an OFT executor is configured for an underlying.
    /// @param underlying Underlying token address.
    /// @param executor Executor contract address.
    event OftExecutorSet(address indexed underlying, address indexed executor);

    error LZBridge_NotEnoughFees();
    error LZBridge_ChainNotRegistered();
    error LZBridge_DestinationMismatch();
    error LZBridge_DifferentInnerToken();
    error LZBridge_NoOft();
    error LZBridge_TokenMismatch();
    error LZBridge_ExecutorNotSet();
    error LZBridge_ExecutorNoCode();
    error LZBridge_OnlyEndpoint();
    error LZBridge_BadFrom();
    error LZBridge_RefunderNotValid();
    error LZBridge_EndpointZero();

    /// @notice Creates the unified LayerZero bridge.
    /// @param _roles Roles contract used by BaseBridge.
    /// @param _endpoint LayerZero endpoint allowed to call lzCompose().
    constructor(address _roles, address _endpoint) BaseBridge(_roles) {
        if (_endpoint == address(0)) revert LZBridge_EndpointZero();
        ENDPOINT = _endpoint;
    }

    /// @notice Sets the OFT bridge contract for an underlying token.
    /// @param underlying Underlying token.
    /// @param bridgeContract OFT/bridge contract to use for that underlying.
    function setBridgeContract(address underlying, address bridgeContract) external onlyBridgeConfigurator {
        bridgeContracts[underlying] = bridgeContract;
        emit BridgeContractSet(underlying, bridgeContract);
    }

    /// @notice Sets the executor contract for an underlying token.
    /// @param underlying Underlying token.
    /// @param bridgeContract Executor contract (kept as name for backward-compat with existing calls/logs).
    function setOftExecutorContract(address underlying, address bridgeContract) external onlyBridgeConfigurator {
        oftExecutors[underlying] = bridgeContract;
        emit OftExecutorSet(underlying, bridgeContract);
    }

    /// @notice Sends a message + tokens via OFT, delegating to an executor per underlying.
    /// @param _extractedAmount Amount extracted by the rebalancer.
    /// @param _market Market address expected inside `_message`.
    /// @param _dstChainId Destination chain id (eid).
    /// @param _token Underlying token (must match market.underlying()).
    /// @param _message ABI-encoded (market, amountLD, minAmountLD, extraOptions).
    /// @param _extraData ABI-encoded refund address.
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes calldata _message,
        bytes calldata _extraData
    ) external payable onlyRebalancer {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());

        SendMsgLocalVars memory v;

        (v.market,,,) = abi.decode(_message, (address, uint256, uint256, bytes));
        require(_market == v.market, LZBridge_DestinationMismatch());

        v.underlying = ImTokenMinimal(_market).underlying();
        require(v.underlying == _token, LZBridge_TokenMismatch());
        require(oftExecutors[v.underlying] != address(0), LZBridge_ExecutorNotSet());

        (v.fees, v.sendParam) = _getFee(_dstChainId, _message);
        require(msg.value >= v.fees.nativeFee, LZBridge_NotEnoughFees());
        require(_extractedAmount == v.sendParam.amountLD, BaseBridge_AmountMismatch());

        v.bridgeContract = bridgeContracts[v.underlying];
        if (v.bridgeContract == address(0)) {
            v.bridgeContract = v.underlying;
        }

        address refunder = abi.decode(_extraData, (address));
        require(refunder != address(0), LZBridge_RefunderNotValid());

        MessagingReceipt memory msgReceipt =
            _delegateExecuteSend(v.underlying, v.bridgeContract, v.sendParam, v.fees, msg.sender, refunder);

        emit MsgSent(_dstChainId, v.market, v.sendParam.amountLD, v.sendParam.minAmountLD, msgReceipt.guid);
    }

    /// @notice LayerZero compose callback. Delegates compose execution to the configured executor.
    /// @param from Expected to be the bridge contract (OFT) for the decoded underlying.
    /// @param guid Unused.
    /// @param message ABI-encoded (market).
    /// @param executor Unused.
    /// @param extraData Unused.
    function lzCompose(address from, bytes32 guid, bytes calldata message, address executor, bytes calldata extraData)
        external
        payable
    {
        guid;
        executor;
        extraData;

        require(msg.sender == ENDPOINT, LZBridge_OnlyEndpoint());

        address market = abi.decode(message, (address));
        address underlying = ImTokenMinimal(market).underlying();

        address bridgeContract = bridgeContracts[underlying];
        if (bridgeContract == address(0)) {
            bridgeContract = underlying;
        }

        require(from == bridgeContract, LZBridge_BadFrom());

        address oftExecutor = oftExecutors[underlying];
        require(oftExecutor != address(0), LZBridge_ExecutorNotSet());

        bytes memory data =
            abi.encodeWithSelector(IOftMessageExecutor.executeCompose.selector, market, underlying, bridgeContract);

        // slither-disable-next-line controlled-delegatecall
        (bool ok, bytes memory ret) = oftExecutor.delegatecall(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    /// @notice Processes any stored/uncomposed messages for a market (via executor).
    /// @param _market Market address.
    function processUncomposedMessages(address _market) external payable onlyBridgeConfigurator {
        address underlying = ImTokenMinimal(_market).underlying();

        address bridgeContract = bridgeContracts[underlying];
        if (bridgeContract == address(0)) {
            bridgeContract = underlying;
        }

        address oftExecutor = oftExecutors[underlying];
        require(oftExecutor != address(0), LZBridge_ExecutorNotSet());

        bytes memory data =
            abi.encodeWithSelector(IOftMessageExecutor.processUncomposed.selector, _market, underlying, bridgeContract);

        // slither-disable-next-line controlled-delegatecall
        (bool ok, bytes memory ret) = oftExecutor.delegatecall(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    /// @notice Quotes the native fee required to send the message.
    /// @param _dstChainId Destination chain id (eid).
    /// @param _message ABI-encoded (market, amountLD, minAmountLD, extraOptions).
    /// @param _extraData Unused.
    /// @return nativeFee Native fee quoted by the OFT.
    function getFee(uint32 _dstChainId, bytes calldata _message, bytes calldata _extraData)
        external
        view
        returns (uint256 nativeFee)
    {
        _extraData;
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());

        (MessagingFee memory fees,) = _getFee(_dstChainId, _message);
        return fees.nativeFee;
    }

    /// @notice Delegates executeSend to the configured executor and decodes the MessagingReceipt.
    /// @param underlying Underlying token.
    /// @param bridgeContract OFT/bridge contract used for the send.
    /// @param params LayerZero SendParam.
    /// @param fees LayerZero MessagingFee.
    /// @param rebalancer Caller (expected rebalancer).
    /// @param refundAddress Refund address for any extra native fee.
    /// @return r MessagingReceipt returned by the executor.
    function _delegateExecuteSend(
        address underlying,
        address bridgeContract,
        SendParam memory params,
        MessagingFee memory fees,
        address rebalancer,
        address refundAddress
    ) private returns (MessagingReceipt memory r) {
        address oftExecutor = oftExecutors[underlying];
        require(oftExecutor != address(0), LZBridge_ExecutorNotSet());
        require(oftExecutor.code.length != 0, LZBridge_ExecutorNoCode());

        bytes memory data = abi.encodeWithSelector(
            IOftMessageExecutor.executeSend.selector,
            underlying,
            bridgeContract,
            params,
            fees,
            rebalancer,
            refundAddress
        );

        (bool ok, bytes memory ret) = oftExecutor.delegatecall(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }

        r = abi.decode(ret, (MessagingReceipt));
    }

    /// @notice Internal helper to quote fees and build SendParam.
    /// @param dstEid Destination chain id (eid).
    /// @param _message ABI-encoded (market, amountLD, minAmountLD, extraOptions).
    /// @return fees LayerZero messaging fees.
    /// @return lzSendParams LayerZero send parameters.
    function _getFee(uint32 dstEid, bytes calldata _message)
        private
        view
        returns (MessagingFee memory fees, SendParam memory lzSendParams)
    {
        (address market, uint256 amountLD, uint256 minAmountLD, bytes memory extraOptions) =
            abi.decode(_message, (address, uint256, uint256, bytes));

        address underlying = ImTokenMinimal(market).underlying();
        address bridgeContract = bridgeContracts[underlying];
        if (bridgeContract == address(0)) {
            bridgeContract = underlying;
        }

        lzSendParams = SendParam({
            dstEid: dstEid,
            to: bytes32(uint256(uint160(bridgeContract))),
            amountLD: amountLD,
            minAmountLD: minAmountLD,
            extraOptions: extraOptions,
            composeMsg: abi.encode(market),
            oftCmd: ""
        });

        fees = ILayerZeroOFT(bridgeContract).quoteSend(lzSendParams, false);
    }
}
