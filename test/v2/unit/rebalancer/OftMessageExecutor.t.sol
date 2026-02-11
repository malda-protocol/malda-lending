// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseOftMessageExecutor} from "src/rebalancer/bridges/helpers/BaseOftMessageExecutor.sol";
import {rsEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/rsEthOftMessageExecutor.sol";
import {weEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/weEthOftMessageExecutor.sol";

import {MessagingFee, SendParam} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {
    MockOFTToken,
    MockWrapperToken,
    RevertingOFTToken,
    RevertingWrapperToken,
    TestToken
} from "test/v2/mocks/rebalancer/OftMessageExecutorMocks.t.sol";
import {BaseOftExecutorHarness} from "test/v2/unit/rebalancer/harness/BaseOftExecutorHarness.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract BaseOftMessageExecutorTest is BaseTest {
    BaseOftExecutorHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new BaseOftExecutorHarness();
    }

    ////////////////////////////////////////////////////////////
    //                   pullFromRebalancer                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_pullFromRebalancer_success(uint256 amountRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        address rebalancer = users.alice;
        uint256 amount = bound(amountRaw, 1, 1e24);
        underlying.mint(rebalancer, amount);

        vm.prank(rebalancer);
        underlying.approve(address(harness), amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.pullFromRebalancer(address(underlying), amount, rebalancer);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            underlying.balanceOf(address(harness)),
            amount,
            "harness did not pull the expected amount of underlying from the rebalancer"
        );
    }

    function test_unit_pullFromRebalancer_revertsWith_Executor_NotRebalancer() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_NotRebalancer.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.pullFromRebalancer(address(underlying), 1e18, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                  fallbackToUnderlying                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_fallbackToUnderlying_success_transfersWhenUnderlyingBridge(uint256 amountRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        address market = users.bob;

        uint256 amount = bound(amountRaw, 1, 1e24);
        underlying.mint(address(harness), amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.fallbackToUnderlying(market, address(underlying), address(underlying));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(underlying.balanceOf(market), amount, "market did not receive the expected underlying amount");
    }

    function test_unit_fallbackToUnderlying_success_returnsWhenNoOftBalance() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        TestToken oft = new TestToken("OFT", "OFT");
        address market = users.bob;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.fallbackToUnderlying(market, address(underlying), address(oft));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(underlying.balanceOf(market), 0, "expected underlying.balanceOf(market) to equal 0");
    }

    function test_fuzz_fallbackToUnderlying_success_depositsAndTransfers(uint256 amountRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        address market = users.bob;

        uint256 amount = bound(amountRaw, 1, 1e24);
        oft.mint(address(harness), amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.fallbackToUnderlying(market, address(underlying), address(oft));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(underlying.balanceOf(market), amount, "market did not receive the expected wrapped underlying amount");
    }

    ////////////////////////////////////////////////////////////
    //                      verifyMinted                      //
    ////////////////////////////////////////////////////////////

    function test_unit_verifyMinted_revertsWith_Executor_AmountMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.verifyMinted(address(oft), 1);
    }

    function test_unit_verifyMinted_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        oft.mint(address(harness), 1);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.verifyMinted(address(oft), 1);
    }

    ////////////////////////////////////////////////////////////
    //                         sendOFT                        //
    ////////////////////////////////////////////////////////////

    function test_unit_sendOFT_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        SendParam memory params = _sendParam(1);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.sendOFT(address(oft), params, fees, users.bob);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (,, uint256 amountLD, uint256 minAmountLD,,,) = oft.lastParams();
        (uint256 nativeFee, uint256 lzTokenFee) = oft.lastFee();
        assertEq(oft.lastRefund(), users.bob, "expected oft.lastRefund() to equal users.bob");
        assertEq(amountLD, params.amountLD, "expected amountLD to equal params.amountLD");
        assertEq(minAmountLD, params.minAmountLD, "expected minAmountLD to equal params.minAmountLD");
        assertEq(nativeFee, fees.nativeFee, "expected nativeFee to equal fees.nativeFee");
        assertEq(lzTokenFee, fees.lzTokenFee, "expected lzTokenFee to equal fees.lzTokenFee");
    }

    ////////////////////////////////////////////////////////////
    //                    processUncomposed                   //
    ////////////////////////////////////////////////////////////

    function test_unit_processUncomposed_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        address market = users.bob;

        underlying.mint(address(harness), 1e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.processUncomposed(market, address(underlying), address(underlying));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(underlying.balanceOf(market), 1e18, "expected underlying.balanceOf(market) to equal 1e18");
    }

    ////////////////////////////////////////////////////////////
    //                     executeCompose                     //
    ////////////////////////////////////////////////////////////

    function test_unit_executeCompose_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        address market = users.bob;

        underlying.mint(address(harness), 1e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.executeCompose(market, address(underlying), address(underlying));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(underlying.balanceOf(market), 1e18, "expected underlying.balanceOf(market) to equal 1e18");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _sendParam(uint256 amount) internal view returns (SendParam memory) {
        return SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
    }
}

contract rsEthOftMessageExecutorTest is BaseTest {
    rsEthOftMessageExecutor internal executor;

    function setUp() public override {
        super.setUp();
        executor = new rsEthOftMessageExecutor();
    }

    ////////////////////////////////////////////////////////////
    //                      executeSend                       //
    ////////////////////////////////////////////////////////////

    function test_unit_executeSend_success_withWrapper() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        underlying.setAllowed(address(oft), true);

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 2e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 2e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(2e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oft.balanceOf(address(executor)), 2e18, "expected oft.balanceOf(address(executor)) to equal 2e18");
        (,, uint256 amountLD,,,,) = oft.lastParams();
        assertEq(oft.lastRefund(), users.bob, "expected oft.lastRefund() to equal users.bob");
        assertEq(amountLD, params.amountLD, "expected amountLD to equal params.amountLD");
    }

    function test_unit_executeSend_success_withWrapper_whenAmountZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        underlying.setAllowed(address(oft), true);

        address rebalancer = users.alice;
        vm.prank(rebalancer);
        underlying.approve(address(executor), 0);

        SendParam memory params = _sendParam(0);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oft.balanceOf(address(executor)), 0, "expected oft.balanceOf(address(executor)) to equal 0");
        assertEq(oft.lastRefund(), users.bob, "expected oft.lastRefund() to equal users.bob");
    }

    function test_unit_executeSend_revertsWith_Executor_NotRebalancer() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockOFTToken underlying = new MockOFTToken("U", "U", address(0));
        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_NotRebalancer.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(underlying), params, fees, address(this), users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_DifferentInnerToken() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(rsEthOftMessageExecutor.Executor_DifferentInnerToken.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_NoOft() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        RevertingWrapperToken underlying = new RevertingWrapperToken();
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_NoOft.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_AmountMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        underlying.setAllowed(address(oft), true);
        underlying.setMintOnWithdraw(false);

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_success_whenBridgeIsUnderlying() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockOFTToken underlying = new MockOFTToken("OFT", "OFT", address(0));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(underlying), params, fees, rebalancer, users.bob);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (,, uint256 amountLD,,,,) = underlying.lastParams();
        assertEq(underlying.lastRefund(), users.bob, "expected underlying.lastRefund() to equal users.bob");
        assertEq(amountLD, params.amountLD, "expected amountLD to equal params.amountLD");
    }

    // NOTE (as of 2026-02-11): unreachable invariant.
    // The rsETH catch branch is terminal (`require(false, Executor_NoOft())`),
    // so execution cannot continue when `allowedTokens` reverts.
    function test_unit_unreachableInvariant_executeSendCatchBranchIsTerminal() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        RevertingWrapperToken underlying = new RevertingWrapperToken();
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_NoOft.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _sendParam(uint256 amount) internal view returns (SendParam memory) {
        return SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
    }
}

contract weEthOftMessageExecutorTest is BaseTest {
    weEthOftMessageExecutor internal executor;

    function setUp() public override {
        super.setUp();
        executor = new weEthOftMessageExecutor();
    }

    function test_unit_executeSend_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (,, uint256 amountLD,,,,) = oft.lastParams();
        assertEq(oft.lastRefund(), users.bob, "expected oft.lastRefund() to equal users.bob");
        assertEq(amountLD, params.amountLD, "expected amountLD to equal params.amountLD");
    }

    function test_unit_executeSend_revertsWith_Executor_NotRebalancer() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockOFTToken underlying = new MockOFTToken("U", "U", address(0));
        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_NotRebalancer.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(underlying), params, fees, address(this), users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_DifferentInnerToken() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        TestToken other = new TestToken("X", "X");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(other));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(weEthOftMessageExecutor.Executor_DifferentInnerToken.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_NoOft() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        TestToken underlying = new TestToken("U", "U");
        RevertingOFTToken bad = new RevertingOFTToken();

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.startPrank(rebalancer);
        underlying.approve(address(executor), 1e18);
        vm.stopPrank();

        SendParam memory params = _sendParam(1e18);
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseOftMessageExecutor.Executor_NoOft.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        executor.executeSend(address(underlying), address(bad), params, fees, rebalancer, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _sendParam(uint256 amount) internal view returns (SendParam memory) {
        return SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: amount,
            minAmountLD: amount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
    }
}
