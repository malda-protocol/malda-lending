// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";
import {IOftMessageExecutor} from "src/interfaces/IOftMessageExecutor.sol";
import {
    ILayerZeroOFT,
    SendParam,
    MessagingFee,
    OFTLimit,
    OFTReceipt,
    OFTFeeDetail
} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";

contract LZBridgeMockMarket {
    address public underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }
}

contract LZBridgeMockOFT is ILayerZeroOFT {
    MessagingFee public quoteFee;
    SendParam public lastSendParams;
    MessagingFee public lastSendFee;
    address public lastRefund;
    address public innerToken;

    constructor(address _innerToken) {
        innerToken = _innerToken;
    }

    function setQuoteFee(uint256 nativeFee, uint256 lzTokenFee) external {
        quoteFee = MessagingFee({nativeFee: nativeFee, lzTokenFee: lzTokenFee});
    }

    function oftVersion() external pure returns (bytes4 interfaceId, uint64 version) {
        return (bytes4(0), 0);
    }

    function token() external view returns (address) {
        return innerToken;
    }

    function approvalRequired() external pure returns (bool) {
        return false;
    }

    function sharedDecimals() external pure returns (uint8) {
        return 18;
    }

    function quoteOFT(SendParam calldata)
        external
        pure
        returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory)
    {
        return (OFTLimit({minAmountLD: 0, maxAmountLD: 0}), new OFTFeeDetail[](0), OFTReceipt(0, 0));
    }

    function quoteSend(SendParam calldata, bool) external view returns (MessagingFee memory) {
        return quoteFee;
    }

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        returns (MessagingReceipt memory receipt, OFTReceipt memory oftReceipt)
    {
        lastSendParams = _sendParam;
        lastSendFee = _fee;
        lastRefund = _refundAddress;
        receipt = MessagingReceipt({guid: bytes32("guid"), nonce: 1, fee: _fee});
        oftReceipt = OFTReceipt({amountSentLD: _sendParam.amountLD, amountReceivedLD: _sendParam.amountLD});
    }
}

contract LZBridgeMockExecutor is IOftMessageExecutor {
    function executeSend(address, address, SendParam calldata, MessagingFee calldata fees, address, address)
        external
        payable
        returns (MessagingReceipt memory receipt)
    {
        receipt = MessagingReceipt({guid: bytes32("guid"), nonce: 1, fee: fees});
    }

    function processUncomposed(address, address, address) external payable {}

    function executeCompose(address, address, address) external payable {}
}

contract LZBridgeRevertingExecutor is IOftMessageExecutor {
    error ExecutorRevert();

    function executeSend(address, address, SendParam calldata, MessagingFee calldata, address, address)
        external
        payable
        returns (MessagingReceipt memory)
    {
        revert ExecutorRevert();
    }

    function processUncomposed(address, address, address) external payable {
        revert ExecutorRevert();
    }

    function executeCompose(address, address, address) external payable {
        revert ExecutorRevert();
    }
}

contract LZUnifiedBridgeUnitTest is Test {
    MockRoles internal roles;
    LZUnifiedBridge internal bridge;
    LZBridgeMockOFT internal oft;
    LZBridgeMockExecutor internal executor;
    LZBridgeMockMarket internal market;

    uint32 internal dstChainId = 101;
    uint256 internal amount = 1e18;
    uint256 internal minAmount = 0.9e18;

    function setUp() public {
        roles = new MockRoles();
        roles.setAllowed(address(this), true);

        bridge = new LZUnifiedBridge(address(roles), address(this));
        oft = new LZBridgeMockOFT(address(0xBEEF));
        executor = new LZBridgeMockExecutor();
        market = new LZBridgeMockMarket(address(oft));

        bridge.setOftExecutorContract(address(oft), address(executor));
    }

    function _message() internal view returns (bytes memory) {
        return abi.encode(address(market), amount, minAmount, bytes("extra"));
    }

    function test_constructor_revertWhenEndpointZero() external {
        vm.expectRevert(LZUnifiedBridge.LZBridge_EndpointZero.selector);
        new LZUnifiedBridge(address(roles), address(0));
    }

    function test_setBridgeContract_updatesMapping() external {
        address bridgeContract = address(0x1234);
        bridge.setBridgeContract(address(oft), bridgeContract);
        assertEq(bridge.bridgeContracts(address(oft)), bridgeContract);
    }

    function test_setOftExecutorContract_updatesMapping() external {
        address newExecutor = address(0x5678);
        bridge.setOftExecutorContract(address(oft), newExecutor);
        assertEq(bridge.oftExecutors(address(oft)), newExecutor);
    }

    function test_sendMsg_success() external {
        oft.setQuoteFee(1 ether, 0);

        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectEmit(true, true, true, true);
        emit LZUnifiedBridge.MsgSent(dstChainId, address(market), amount, minAmount, bytes32("guid"));

        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_sendMsg_revertWhenChainNotRegistered() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);
        bridge.sendMsg(amount, address(market), 0, address(oft), message, extraData);
    }

    function test_sendMsg_revertWhenDestinationMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory badMessage = abi.encode(address(0xBAD), amount, minAmount, bytes(""));
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectRevert(LZUnifiedBridge.LZBridge_DestinationMismatch.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), badMessage, extraData);
    }

    function test_sendMsg_revertWhenTokenMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectRevert(LZUnifiedBridge.LZBridge_TokenMismatch.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(0xDEAD), message, extraData);
    }

    function test_sendMsg_revertWhenExecutorNotSet() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_sendMsg_revertWhenNotEnoughFees() external {
        oft.setQuoteFee(2 ether, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectRevert(LZUnifiedBridge.LZBridge_NotEnoughFees.selector);
        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_sendMsg_revertWhenAmountMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectRevert(abi.encodeWithSelector(BaseBridge.BaseBridge_AmountMismatch.selector, amount + 1, amount));
        bridge.sendMsg(amount + 1, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_sendMsg_revertWhenRefunderZero() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0));

        vm.expectRevert(LZUnifiedBridge.LZBridge_RefunderNotValid.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_sendMsg_revertWhenExecutorHasNoCode() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bridge2.setOftExecutorContract(address(oft), address(1));
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));
        oft.setQuoteFee(0, 0);

        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNoCode.selector);
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_lzCompose_success() external {
        bytes memory message = abi.encode(address(market));
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_lzCompose_revertWhenNotEndpoint() external {
        bytes memory message = abi.encode(address(market));
        vm.prank(address(0xBEEF));
        vm.expectRevert(LZUnifiedBridge.LZBridge_OnlyEndpoint.selector);
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_lzCompose_revertWhenBadFrom() external {
        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZUnifiedBridge.LZBridge_BadFrom.selector);
        bridge.lzCompose(address(0xBAD), bytes32(0), message, address(0), bytes(""));
    }

    function test_lzCompose_revertWhenExecutorNotSet() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_lzCompose_bubblesExecutorRevert() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));

        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_processUncomposedMessages_success() external {
        bridge.processUncomposedMessages(address(market));
    }

    function test_processUncomposedMessages_revertWhenExecutorNotSet() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.processUncomposedMessages(address(market));
    }

    function test_processUncomposedMessages_bubblesExecutorRevert() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));

        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.processUncomposedMessages(address(market));
    }

    function test_getFee_returnsNativeFee() external {
        oft.setQuoteFee(0.5 ether, 0);
        uint256 fee = bridge.getFee(dstChainId, _message(), "");
        assertEq(fee, 0.5 ether);
    }

    function test_getFee_revertWhenChainNotRegistered() external {
        oft.setQuoteFee(0, 0);
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);
        bridge.getFee(0, _message(), "");
    }

    function test_sendMsg_bubblesExecutorRevert() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));
        oft.setQuoteFee(0, 0);

        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0xBEEF));

        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }
}
