// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {LZUnifiedBridge} from "src/rebalancer/bridges/LZUnifiedBridge.sol";

import {MessagingFee, SendParam, ILayerZeroOFT} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {IOftMessageExecutor} from "src/interfaces/IOftMessageExecutor.sol";

import {MockRoles} from "test/mocks/MockRoles.sol";
import {
    LZBridgeMockExecutor,
    LZBridgeMockMarket,
    LZBridgeMockOFT,
    LZBridgeRevertingExecutor
} from "test/v2/mocks/rebalancer/LZUnifiedBridgeMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract LZOftSendExecutor is IOftMessageExecutor {
    function executeSend(
        address,
        address bridgeContract,
        SendParam calldata params,
        MessagingFee calldata fees,
        address,
        address refundAddress
    ) external payable returns (MessagingReceipt memory receipt) {
        // solhint-disable-next-line check-send-result
        (receipt,) = ILayerZeroOFT(bridgeContract).send{value: fees.nativeFee}(params, fees, refundAddress);
    }

    function processUncomposed(address, address, address) external payable {}

    function executeCompose(address, address, address) external payable {}
}

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

    function test_unit_setBridgeContract_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address bridgeContract = users.alice;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.BridgeContractSet(address(oft), bridgeContract);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setBridgeContract(address(oft), bridgeContract);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            bridge.bridgeContracts(address(oft)),
            bridgeContract,
            "expected bridge.bridgeContracts(address(oft)) to equal bridgeContract"
        );
    }

    ////////////////////////////////////////////////////////////
    //                 setOftExecutorContract                 //
    ////////////////////////////////////////////////////////////

    function test_unit_setOftExecutorContract_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address newExecutor = users.carol;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.OftExecutorSet(address(oft), newExecutor);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setOftExecutorContract(address(oft), newExecutor);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            bridge.oftExecutors(address(oft)),
            newExecutor,
            "expected bridge.oftExecutors(address(oft)) to equal newExecutor"
        );
    }

    ////////////////////////////////////////////////////////////
    //                         sendMsg                        //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_success() external {
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

    function test_fuzz_sendMsg_success(uint256 amountRaw, uint256 minAmountRaw, uint96 feeRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        LZUnifiedBridge bridge2 = new LZUnifiedBridge(address(roles), address(this));
        LZOftSendExecutor sendExecutor = new LZOftSendExecutor();
        bridge2.setOftExecutorContract(address(oft), address(sendExecutor));

        uint256 amountFuzzed = bound(amountRaw, 1, 1e24);
        uint256 minAmountFuzzed = bound(minAmountRaw, 0, amountFuzzed);
        uint256 fee = uint256(bound(feeRaw, 0, 10 ether));

        vm.deal(address(this), fee);
        oft.setQuoteFee(fee, 0);
        bytes memory message = abi.encode(address(market), amountFuzzed, minAmountFuzzed, bytes("extra"));
        bytes memory extraData = _extraData(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit LZUnifiedBridge.MsgSent(dstChainId, address(market), amountFuzzed, minAmountFuzzed, bytes32("guid"));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge2.sendMsg{value: fee}(amountFuzzed, address(market), dstChainId, address(oft), message, extraData);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (uint32 dstEid,, uint256 amountLD, uint256 minAmountLD,,,) = oft.lastSendParams();
        (uint256 nativeFee,) = oft.lastSendFee();

        assertEq(oft.lastRefund(), users.bob, "refund address was not forwarded to the OFT send");
        assertEq(dstEid, dstChainId, "destination chain id was not forwarded to the OFT send");
        assertEq(amountLD, amountFuzzed, "amountLD was not forwarded to the OFT send");
        assertEq(minAmountLD, minAmountFuzzed, "minAmountLD was not forwarded to the OFT send");
        assertEq(nativeFee, fee, "nativeFee was not forwarded to the OFT send");
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

    function test_unit_lzCompose_success() external {
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

    function test_unit_processUncomposedMessages_success() external {
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

    function test_fuzz_getFee_success(uint256 fuzzFee) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(fuzzFee, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 fee = bridge.getFee(dstChainId, _message(), "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(fee, fuzzFee, "expected fee to equal fuzzFee");
    }

    function test_unit_getFee_revertsWith_LZBridge_ChainNotRegistered() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oft.setQuoteFee(0, 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(LZUnifiedBridge.LZBridge_ChainNotRegistered.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(0, _message(), "");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _message() internal view returns (bytes memory) {
        return abi.encode(address(market), amount, minAmount, bytes("extra"));
    }

    function _extraData(address refunder) internal pure returns (bytes memory) {
        return abi.encode(refunder);
    }
}
