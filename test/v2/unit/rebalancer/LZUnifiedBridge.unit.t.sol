// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";
import {
    LZBridgeMockExecutor,
    LZBridgeMockMarket,
    LZBridgeMockOFT,
    LZBridgeRevertingExecutor
} from "test/v2/mocks/rebalancer/LZUnifiedBridgeMocks.t.sol";

contract LZUnifiedBridgeUnitTest is BaseTest {
    MockRoles internal roles;
    LZUnifiedBridge internal bridge;
    LZBridgeMockOFT internal oft;
    LZBridgeMockExecutor internal executor;
    LZBridgeMockMarket internal market;

    uint32 internal dstChainId = LZ_DST_CHAIN_ID;
    uint256 internal amount = 1e18;
    uint256 internal minAmount = 0.9e18;

    function setUp() public override {
        super.setUp();
        roles = new MockRoles();
        roles.setAllowed(address(this), true);

        bridge = new LZUnifiedBridge(address(roles), address(this));
        oft = new LZBridgeMockOFT(users.bob);
        executor = new LZBridgeMockExecutor();
        market = new LZBridgeMockMarket(address(oft));

        bridge.setOftExecutorContract(address(oft), address(executor));
    }

    function _message() internal view returns (bytes memory) {
        return abi.encode(address(market), amount, minAmount, bytes("extra"));
    }

    ////////////////////////////////////////////////////////////
    //                       Constructor                        //
    ////////////////////////////////////////////////////////////

    function test_unitConstructor_revertsWith_revertWhenEndpointZero() external {
        vm.expectRevert(LZUnifiedBridge.LZBridge_EndpointZero.selector);
        new LZUnifiedBridge(address(roles), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                    SetBridgeContract                     //
    ////////////////////////////////////////////////////////////

    function test_unitSetBridgeContract_success_updatesMapping() external {
        address bridgeContract = users.alice;
        bridge.setBridgeContract(address(oft), bridgeContract);
        assertEq(bridge.bridgeContracts(address(oft)), bridgeContract);
    }

    ////////////////////////////////////////////////////////////
    //                  SetOftExecutorContract                  //
    ////////////////////////////////////////////////////////////

    function test_unitSetOftExecutorContract_success_updatesMapping() external {
        address newExecutor = users.carol;
        bridge.setOftExecutorContract(address(oft), newExecutor);
        assertEq(bridge.oftExecutors(address(oft)), newExecutor);
    }

    ////////////////////////////////////////////////////////////
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_success_success() external {
        oft.setQuoteFee(1 ether, 0);

        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectEmit(true, true, true, true);
        emit LZUnifiedBridge.MsgSent(dstChainId, address(market), amount, minAmount, bytes32("guid"));

        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenChainNotRegistered() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);
        bridge.sendMsg(amount, address(market), 0, address(oft), message, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenDestinationMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory badMessage = abi.encode(users.carol, amount, minAmount, bytes(""));
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_DestinationMismatch.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), badMessage, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenTokenMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_TokenMismatch.selector);
        bridge.sendMsg(amount, address(market), dstChainId, users.alice, message, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenExecutorNotSet() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenNotEnoughFees() external {
        oft.setQuoteFee(2 ether, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_NotEnoughFees.selector);
        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenAmountMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(abi.encodeWithSelector(BaseBridge.BaseBridge_AmountMismatch.selector, amount + 1, amount));
        bridge.sendMsg(amount + 1, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenRefunderZero() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0));

        vm.expectRevert(LZUnifiedBridge.LZBridge_RefunderNotValid.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unitSendMsg_revertsWith_revertWhenExecutorHasNoCode() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bridge2.setOftExecutorContract(address(oft), address(1));
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);
        oft.setQuoteFee(0, 0);

        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNoCode.selector);
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                        LzCompose                         //
    ////////////////////////////////////////////////////////////

    function test_unitLzCompose_success_success() external {
        bytes memory message = abi.encode(address(market));
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unitLzCompose_revertsWith_revertWhenNotEndpoint() external {
        bytes memory message = abi.encode(address(market));
        vm.prank(users.alice);
        vm.expectRevert(LZUnifiedBridge.LZBridge_OnlyEndpoint.selector);
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unitLzCompose_revertsWith_revertWhenBadFrom() external {
        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZUnifiedBridge.LZBridge_BadFrom.selector);
        bridge.lzCompose(users.carol, bytes32(0), message, address(0), bytes(""));
    }

    function test_unitLzCompose_revertsWith_revertWhenExecutorNotSet() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unitLzCompose_revertsWith_bubblesExecutorRevert() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));

        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    ////////////////////////////////////////////////////////////
    //                ProcessUncomposedMessages                 //
    ////////////////////////////////////////////////////////////

    function test_unitProcessUncomposedMessages_success_success() external {
        bridge.processUncomposedMessages(address(market));
    }

    function test_unitProcessUncomposedMessages_revertsWith_revertWhenExecutorNotSet() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.processUncomposedMessages(address(market));
    }

    function test_unitProcessUncomposedMessages_revertsWith_bubblesExecutorRevert() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));

        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.processUncomposedMessages(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                          GetFee                          //
    ////////////////////////////////////////////////////////////

    function test_unitGetFee_success_returnsNativeFee() external {
        oft.setQuoteFee(0.5 ether, 0);
        uint256 fee = bridge.getFee(dstChainId, _message(), "");
        assertEq(fee, 0.5 ether);
    }

    function test_unitGetFee_revertsWith_revertWhenChainNotRegistered() external {
        oft.setQuoteFee(0, 0);
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);
        bridge.getFee(0, _message(), "");
    }

    ////////////////////////////////////////////////////////////
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_revertsWith_bubblesExecutorRevert() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));
        oft.setQuoteFee(0, 0);

        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }
}
