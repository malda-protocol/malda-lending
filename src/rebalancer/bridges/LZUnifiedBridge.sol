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

contract LZUnifiedBridge is BaseBridge, IBridge {
    using SafeERC20 for IERC20;

    address public immutable endpoint;

    struct SendMsgLocalVars {
        address market;
        address underlying;
        address bridgeContract;
        MessagingFee fees;
        SendParam sendParam;
    }

    mapping(address => address) public bridgeContracts;
    mapping(address => address) public oftExecutors;

    event MsgSent(
        uint32 indexed dstChainId,
        address indexed market,
        uint256 amountLD,
        uint256 minAmountLD,
        bytes32 guid
    );
    event BridgeContractSet(address indexed underlying, address indexed bridgeContract);
    event OftExecutorSet(address indexed underlying, address indexed executor);

    error LZBridge_NotEnoughFees();
    error LZBridge_ChainNotRegistered();
    error LZBridge_DestinationMismatch();
    error LZBridge_DifferentInnerToken();
    error LZBridge_NoOft();
    error LZBridge_TokenMismatch();
    error LZBridge_ExecutorNotSet();
    error LZBridge_OnlyEndpoint();
    error LZBridge_BadFrom();
    error LZBridge_RefunderNotValid();

    constructor(address _roles, address _endpoint) BaseBridge(_roles) {
        endpoint = _endpoint;
    }

    function setBridgeContract(address underlying, address bridgeContract) external onlyBridgeConfigurator {
        bridgeContracts[underlying] = bridgeContract;
        emit BridgeContractSet(underlying, bridgeContract);
    }

    function setOftExecutorContract(address underlying, address bridgeContract) external onlyBridgeConfigurator {
        oftExecutors[underlying] = bridgeContract;
        emit OftExecutorSet(underlying, bridgeContract);
    }

    function getFee(uint32 _dstChainId, bytes memory _message, bytes memory)
        external
        view
        returns (uint256)
    {
        require(_dstChainId > 0, LZBridge_ChainNotRegistered());

        (MessagingFee memory fees,) = _getFee(_dstChainId, _message);
        return fees.nativeFee;
    }

    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes memory _message,
        bytes memory _extraData
    )
        external
        payable
        onlyRebalancer
    {
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

        MessagingReceipt memory msgReceipt = _delegateExecuteSend(
            v.underlying,
            v.bridgeContract,
            v.sendParam,
            v.fees,
            msg.sender,
            refunder
        );

        emit MsgSent(
            _dstChainId,
            v.market,
            v.sendParam.amountLD,
            v.sendParam.minAmountLD,
            msgReceipt.guid
        );
    }

    function lzCompose(
        address from,
        bytes32,
        bytes calldata message,
        address,
        bytes calldata
    ) external payable {
        require(msg.sender == endpoint, LZBridge_OnlyEndpoint());

        (address market) = abi.decode(message, (address));
        address underlying = ImTokenMinimal(market).underlying();

        address bridgeContract = bridgeContracts[underlying];
        if (bridgeContract == address(0)) {
            bridgeContract = underlying;
        }

        require(from == bridgeContract, LZBridge_BadFrom());

        address executor = oftExecutors[underlying];
        require(executor != address(0), LZBridge_ExecutorNotSet());

        bytes memory data = abi.encodeWithSelector(
            IOftMessageExecutor.executeCompose.selector,
            market,
            underlying,
            bridgeContract
        );

        (bool ok, bytes memory ret) = executor.delegatecall(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function processUncomposedMessages(address _market)
        external
        payable
        onlyBridgeConfigurator
    {
        address underlying = ImTokenMinimal(_market).underlying();
        address bridgeContract = bridgeContracts[underlying];
        if (bridgeContract == address(0)) {
            bridgeContract = underlying;
        }

        address executor = oftExecutors[underlying];
        require(executor != address(0), LZBridge_ExecutorNotSet());

        bytes memory data = abi.encodeWithSelector(
            IOftMessageExecutor.processUncomposed.selector,
            _market,
            underlying,
            bridgeContract
        );

        (bool ok, bytes memory ret) = executor.delegatecall(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function _getFee(uint32 dstEid, bytes memory _message)
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

    function _delegateExecuteSend(
        address underlying,
        address bridgeContract,
        SendParam memory params,
        MessagingFee memory fees,
        address rebalancer,
        address refundAddress
    ) private returns (MessagingReceipt memory r) {
        bytes memory data = abi.encodeWithSelector(
            IOftMessageExecutor.executeSend.selector,
            underlying,
            bridgeContract,
            params,
            fees,
            rebalancer,
            refundAddress
        );

        (bool ok, bytes memory ret) = address(oftExecutors[underlying]).delegatecall(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }

        r = abi.decode(ret, (MessagingReceipt));
    }
}
