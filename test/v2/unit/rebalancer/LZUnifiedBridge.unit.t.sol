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
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_LZBridge_EndpointZero() external {
        vm.expectRevert(LZUnifiedBridge.LZBridge_EndpointZero.selector);
        new LZUnifiedBridge(address(roles), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                   SetBridgeContract                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setBridgeContract_success_updatesMapping() external {
        address bridgeContract = users.alice;
        bridge.setBridgeContract(address(oft), bridgeContract);
        assertEq(bridge.bridgeContracts(address(oft)), bridgeContract);
    }

    ////////////////////////////////////////////////////////////
    //                 SetOftExecutorContract                 //
    ////////////////////////////////////////////////////////////

    function test_unit_setOftExecutorContract_success_updatesMapping() external {
        address newExecutor = users.carol;
        bridge.setOftExecutorContract(address(oft), newExecutor);
        assertEq(bridge.oftExecutors(address(oft)), newExecutor);
    }

    ////////////////////////////////////////////////////////////
    //                        Bytes32                         //
    ////////////////////////////////////////////////////////////

    function test_unit_bytes32_success_success() external {
        oft.setQuoteFee(1 ether, 0);

        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectEmit(true, true, true, true);
        emit LZUnifiedBridge.MsgSent(dstChainId, address(market), amount, minAmount, bytes32("guid"));

        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_LZBridge_ChainNotRegistered() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);
        bridge.sendMsg(amount, address(market), 0, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_DestinationMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory badMessage = abi.encode(users.carol, amount, minAmount, bytes(""));
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_DestinationMismatch.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), badMessage, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_TokenMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_TokenMismatch.selector);
        bridge.sendMsg(amount, address(market), dstChainId, users.alice, message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_ExecutorNotSet() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                      SetQuoteFee                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setQuoteFee_revertsWith_LZBridge_NotEnoughFees() external {
        oft.setQuoteFee(2 ether, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZUnifiedBridge.LZBridge_NotEnoughFees.selector);
        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(abi.encodeWithSelector(BaseBridge.BaseBridge_AmountMismatch.selector, amount + 1, amount));
        bridge.sendMsg(amount + 1, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_RefunderNotValid() external {
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = abi.encode(address(0));

        vm.expectRevert(LZUnifiedBridge.LZBridge_RefunderNotValid.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_ExecutorNoCode() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bridge2.setOftExecutorContract(address(oft), address(1));
        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);
        oft.setQuoteFee(0, 0);

        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNoCode.selector);
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                        Bytes32                         //
    ////////////////////////////////////////////////////////////

    function test_unit_bytes32_success_success_variant2() external {
        bytes memory message = abi.encode(address(market));
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    ////////////////////////////////////////////////////////////
    //                       LzCompose                        //
    ////////////////////////////////////////////////////////////

    function test_unit_lzCompose_revertsWith_LZBridge_OnlyEndpoint() external {
        bytes memory message = abi.encode(address(market));
        vm.prank(users.alice);
        vm.expectRevert(LZUnifiedBridge.LZBridge_OnlyEndpoint.selector);
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unit_lzCompose_revertsWith_LZBridge_BadFrom() external {
        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZUnifiedBridge.LZBridge_BadFrom.selector);
        bridge.lzCompose(users.carol, bytes32(0), message, address(0), bytes(""));
    }

    function test_unit_lzCompose_revertsWith_LZBridge_ExecutorNotSet_variant2() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unit_lzCompose_revertsWith_ExecutorRevert() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));

        bytes memory message = abi.encode(address(market));
        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    ////////////////////////////////////////////////////////////
    //               ProcessUncomposedMessages                //
    ////////////////////////////////////////////////////////////

    function test_unit_processUncomposedMessages_success_success() external {
        bridge.processUncomposedMessages(address(market));
    }

    function test_unit_processUncomposedMessages_revertsWith_LZBridge_ExecutorNotSet_variant3() external {
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);
        bridge2.processUncomposedMessages(address(market));
    }

    function test_unit_processUncomposedMessages_revertsWith_ExecutorRevert_variant2() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));

        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.processUncomposedMessages(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                         GetFee                         //
    ////////////////////////////////////////////////////////////

    function test_unit_getFee_success_returnsNativeFee() external {
        oft.setQuoteFee(0.5 ether, 0);
        uint256 fee = bridge.getFee(dstChainId, _message(), "");
        assertEq(fee, 0.5 ether);
    }

    function test_unit_getFee_revertsWith_LZBridge_ChainNotRegistered() external {
        oft.setQuoteFee(0, 0);
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);
        bridge.getFee(0, _message(), "");
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_ExecutorRevert_variant3() external {
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));
        oft.setQuoteFee(0, 0);

        bytes memory message = _message();
        bytes memory extraData = abi.encode(users.bob);

        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }
}
