// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";

import {MockRoles} from "test/mocks/MockRoles.sol";
import {
    LZBridgeMockExecutor,
    LZBridgeMockMarket,
    LZBridgeMockOFT,
    LZBridgeRevertingExecutor
} from "test/v2/mocks/rebalancer/LZUnifiedBridgeMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

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

    function _extraData(address refunder) internal pure returns (bytes memory) {
        return abi.encode(refunder);
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_LZBridge_EndpointZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_EndpointZero.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new LZUnifiedBridge(address(roles), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                    setBridgeContract                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setBridgeContract_success_updatesMappingAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address bridgeContract = users.alice;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.BridgeContractSet(address(oft), bridgeContract);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setBridgeContract(address(oft), bridgeContract);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.bridgeContracts(address(oft)), bridgeContract);
    }

    ////////////////////////////////////////////////////////////
    //                 setOftExecutorContract                 //
    ////////////////////////////////////////////////////////////

    function test_unit_setOftExecutorContract_success_updatesMappingAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address newExecutor = users.carol;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.OftExecutorSet(address(oft), newExecutor);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setOftExecutorContract(address(oft), newExecutor);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.oftExecutors(address(oft)), newExecutor);
    }

    ////////////////////////////////////////////////////////////
    //                         sendMsg                        //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_success_emitsMsgSent() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(1 ether, 0);
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.MsgSent(dstChainId, address(market), amount, minAmount, bytes32("guid"));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_ChainNotRegistered() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, address(market), 0, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_DestinationMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0, 0);
        bytes memory badMessage = abi.encode(users.carol, amount, minAmount, bytes(""));
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_DestinationMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), badMessage, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_TokenMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, address(market), dstChainId, users.alice, message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_ExecutorNotSet() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_NotEnoughFees() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(2 ether, 0);
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_NotEnoughFees.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg{value: 1 ether}(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount + 1, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_RefunderNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = _extraData(address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_RefunderNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_LZBridge_ExecutorNoCode() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bridge2.setOftExecutorContract(address(oft), address(1));
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);
        oft.setQuoteFee(0, 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNoCode.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge2.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    function test_unit_sendMsg_revertsWith_ExecutorRevert() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));
        oft.setQuoteFee(0, 0);
        bytes memory message = _message();
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, address(market), dstChainId, address(oft), message, extraData);
    }

    ////////////////////////////////////////////////////////////
    //                        lzCompose                       //
    ////////////////////////////////////////////////////////////

    function test_unit_lzCompose_success_executes() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory message = abi.encode(address(market));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unit_lzCompose_revertsWith_LZBridge_OnlyEndpoint() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory message = abi.encode(address(market));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_OnlyEndpoint.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unit_lzCompose_revertsWith_LZBridge_BadFrom() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory message = abi.encode(address(market));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_BadFrom.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.lzCompose(users.carol, bytes32(0), message, address(0), bytes(""));
    }

    function test_unit_lzCompose_revertsWith_LZBridge_ExecutorNotSet() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        bytes memory message = abi.encode(address(market));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge2.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    function test_unit_lzCompose_revertsWith_ExecutorRevert() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));
        bytes memory message = abi.encode(address(market));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.lzCompose(address(oft), bytes32(0), message, address(0), bytes(""));
    }

    ////////////////////////////////////////////////////////////
    //               processUncomposedMessages                //
    ////////////////////////////////////////////////////////////

    function test_unit_processUncomposedMessages_success_executes() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.processUncomposedMessages(address(market));
    }

    function test_unit_processUncomposedMessages_revertsWith_LZBridge_ExecutorNotSet() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ExecutorNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge2.processUncomposedMessages(address(market));
    }

    function test_unit_processUncomposedMessages_revertsWith_ExecutorRevert() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZBridgeRevertingExecutor revertExecutor = new LZBridgeRevertingExecutor();
        bridge.setOftExecutorContract(address(oft), address(revertExecutor));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZBridgeRevertingExecutor.ExecutorRevert.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.processUncomposedMessages(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                          getFee                        //
    ////////////////////////////////////////////////////////////

    function test_unit_getFee_success_returnsNativeFee() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0.5 ether, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 fee = bridge.getFee(dstChainId, _message(), "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(fee, 0.5 ether);
    }

    function test_unit_getFee_revertsWith_LZBridge_ChainNotRegistered() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0, 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(0, _message(), "");
    }
}
