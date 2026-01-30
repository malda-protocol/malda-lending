// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {BaseOftMessageExecutor} from "src/rebalancer/bridges/helpers/BaseOftMessageExecutor.sol";
import {rsEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/rsEthOftMessageExecutor.sol";
import {weEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/weEthOftMessageExecutor.sol";

import {SendParam, MessagingFee} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {
    MockOFTToken,
    MockWrapperToken,
    RevertingOFTToken,
    RevertingWrapperToken,
    TestToken
} from "test/v2/mocks/rebalancer/OftMessageExecutorMocks.t.sol";

contract BaseOftExecutorHarness is BaseOftMessageExecutor {
    function executeSend(address, address, SendParam calldata, MessagingFee calldata, address, address)
        external
        payable
        override
        returns (MessagingReceipt memory)
    {
        revert("not implemented");
    }

    function pullFromRebalancer(address underlying, uint256 amount, address rebalancer) external {
        _pullFromRebalancer(underlying, amount, rebalancer);
    }

    function approveToken(address token, address spender, uint256 amount) external {
        _approve(token, spender, amount);
    }

    function sendOFT(address oft, SendParam calldata params, MessagingFee calldata fees, address refundAddress)
        external
        payable
        returns (MessagingReceipt memory)
    {
        return _sendOFT(oft, params, fees, refundAddress);
    }

    function fallbackToUnderlying(address market, address underlying, address bridgeContract) external {
        _fallbackToUnderlying(market, underlying, bridgeContract);
    }

    function verifyMinted(address oft, uint256 required) external view {
        _verifyMinted(oft, required);
    }
}

contract BaseOftMessageExecutorTest is BaseTest {
    BaseOftExecutorHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new BaseOftExecutorHarness();
    }

    ////////////////////////////////////////////////////////////
    //                   PullFromRebalancer                   //
    ////////////////////////////////////////////////////////////

    function test_unit_pullFromRebalancer_success_transfers() external {
        TestToken underlying = new TestToken("U", "U");
        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);

        vm.prank(rebalancer);
        underlying.approve(address(harness), 1e18);

        harness.pullFromRebalancer(address(underlying), 1e18, rebalancer);
        assertEq(underlying.balanceOf(address(harness)), 1e18);
    }

    function test_unit_pullFromRebalancer_revertsWith_Executor_NotRebalancer() external {
        TestToken underlying = new TestToken("U", "U");
        vm.expectRevert(BaseOftMessageExecutor.Executor_NotRebalancer.selector);
        harness.pullFromRebalancer(address(underlying), 1e18, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                  FallbackToUnderlying                  //
    ////////////////////////////////////////////////////////////

    function test_unit_fallbackToUnderlying_success_transfersWhenUnderlyingBridge() external {
        TestToken underlying = new TestToken("U", "U");
        address market = users.bob;

        underlying.mint(address(harness), 2e18);
        harness.fallbackToUnderlying(market, address(underlying), address(underlying));

        assertEq(underlying.balanceOf(market), 2e18);
    }

    function test_unit_fallbackToUnderlying_success_returnsWhenNoOftBalance() external {
        TestToken underlying = new TestToken("U", "U");
        TestToken oft = new TestToken("OFT", "OFT");
        address market = users.bob;

        harness.fallbackToUnderlying(market, address(underlying), address(oft));
        assertEq(underlying.balanceOf(market), 0);
    }

    function test_unit_fallbackToUnderlying_success_depositsAndTransfers() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        address market = users.bob;

        oft.mint(address(harness), 3e18);
        harness.fallbackToUnderlying(market, address(underlying), address(oft));

        assertEq(underlying.balanceOf(market), 3e18);
    }

    ////////////////////////////////////////////////////////////
    //                      VerifyMinted                      //
    ////////////////////////////////////////////////////////////

    function test_unit_verifyMinted_revertsWith_Executor_AmountMismatch() external {
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        vm.expectRevert(BaseOftMessageExecutor.Executor_AmountMismatch.selector);
        harness.verifyMinted(address(oft), 1);
    }

    function test_unit_verifyMinted_success_ok() external {
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        oft.mint(address(harness), 1);
        harness.verifyMinted(address(oft), 1);
    }

    ////////////////////////////////////////////////////////////
    //                        SendOFT                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendOFT_success_callsSend() external {
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(0));
        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1,
            minAmountLD: 1,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        harness.sendOFT(address(oft), params, fees, users.bob);
        assertEq(oft.lastRefund(), users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                   ProcessUncomposed                    //
    ////////////////////////////////////////////////////////////

    function test_unit_processUncomposed_success_transfersUnderlying() external {
        TestToken underlying = new TestToken("U", "U");
        address market = users.bob;

        underlying.mint(address(harness), 1e18);
        harness.processUncomposed(market, address(underlying), address(underlying));

        assertEq(underlying.balanceOf(market), 1e18);
    }

    ////////////////////////////////////////////////////////////
    //                     ExecuteCompose                     //
    ////////////////////////////////////////////////////////////

    function test_unit_executeCompose_success_transfersUnderlying_variant2() external {
        TestToken underlying = new TestToken("U", "U");
        address market = users.bob;

        underlying.mint(address(harness), 1e18);
        harness.executeCompose(market, address(underlying), address(underlying));

        assertEq(underlying.balanceOf(market), 1e18);
    }
}

contract rsEthOftMessageExecutorTest is BaseTest {
    rsEthOftMessageExecutor internal executor;

    function setUp() public override {
        super.setUp();
        executor = new rsEthOftMessageExecutor();
    }

    ////////////////////////////////////////////////////////////
    //                      ExecuteSend                       //
    ////////////////////////////////////////////////////////////

    function test_unit_executeSend_success_successWithWrapper() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        underlying.setAllowed(address(oft), true);

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 2e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 2e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 2e18,
            minAmountLD: 2e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
        assertEq(oft.balanceOf(address(executor)), 2e18);
    }

    function test_unit_executeSend_revertsWith_Executor_DifferentInnerToken_variant2() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(rsEthOftMessageExecutor.Executor_DifferentInnerToken.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_NoOft_variant2() external {
        RevertingWrapperToken underlying = new RevertingWrapperToken();
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(BaseOftMessageExecutor.Executor_NoOft.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_AmountMismatch_variant2() external {
        MockWrapperToken underlying = new MockWrapperToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));
        underlying.setAllowed(address(oft), true);
        underlying.setMintOnWithdraw(false);

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(BaseOftMessageExecutor.Executor_AmountMismatch.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_success_successWhenBridgeIsUnderlying() external {
        MockOFTToken underlying = new MockOFTToken("OFT", "OFT", address(0));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        executor.executeSend(address(underlying), address(underlying), params, fees, rebalancer, users.bob);
    }
}

contract weEthOftMessageExecutorTest is BaseTest {
    weEthOftMessageExecutor internal executor;

    function setUp() public override {
        super.setUp();
        executor = new weEthOftMessageExecutor();
    }

    function test_unit_executeSend_success_success() external {
        TestToken underlying = new TestToken("U", "U");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(underlying));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_DifferentInnerToken() external {
        TestToken underlying = new TestToken("U", "U");
        TestToken other = new TestToken("X", "X");
        MockOFTToken oft = new MockOFTToken("OFT", "OFT", address(other));

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(weEthOftMessageExecutor.Executor_DifferentInnerToken.selector);
        executor.executeSend(address(underlying), address(oft), params, fees, rebalancer, users.bob);
    }

    function test_unit_executeSend_revertsWith_Executor_NoOft() external {
        TestToken underlying = new TestToken("U", "U");
        RevertingOFTToken bad = new RevertingOFTToken();

        address rebalancer = users.alice;
        underlying.mint(rebalancer, 1e18);
        vm.prank(rebalancer);
        underlying.approve(address(executor), 1e18);

        SendParam memory params = SendParam({
            dstEid: 1,
            to: bytes32(uint256(uint160(users.carol))),
            amountLD: 1e18,
            minAmountLD: 1e18,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });
        MessagingFee memory fees = MessagingFee({nativeFee: 0, lzTokenFee: 0});

        vm.expectRevert(BaseOftMessageExecutor.Executor_NoOft.selector);
        executor.executeSend(address(underlying), address(bad), params, fees, rebalancer, users.bob);
    }
}
