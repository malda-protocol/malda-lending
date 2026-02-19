// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeApprove} from "src/libraries/SafeApprove.sol";

import {
    MockApproveNoReturn,
    MockApproveRevert,
    MockApproveReturnFalse,
    MockApproveReturnTrue
} from "test/mocks/libraries/SafeApproveMocks.t.sol";
import {SafeApproveHarness} from "test/harness/libraries/SafeApproveHarness.sol";
import {BaseTest} from "test/utils/BaseTest.t.sol";

contract SafeApproveTest is BaseTest {
    SafeApproveHarness internal harness;

    function setUp() public override {
        super.setUp();

        harness = new SafeApproveHarness();
    }

    ////////////////////////////////////////////////////////////
    //                    callSafeApprove                     //
    ////////////////////////////////////////////////////////////

    function test_unit_callSafeApprove_revertsWith_SafeApprove_NoContract() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(SafeApprove.SafeApprove_NoContract.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafeApprove(users.alice, users.bob, 1);
    }

    function test_unit_callSafeApprove_revertsWith_SafeApprove_Failed_whenRevertingToken() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockApproveRevert token = new MockApproveRevert();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(SafeApprove.SafeApprove_Failed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafeApprove(address(token), users.bob, 1);
    }

    function test_unit_callSafeApprove_revertsWith_SafeApprove_Failed_whenFalseReturn() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockApproveReturnFalse token = new MockApproveReturnFalse();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(SafeApprove.SafeApprove_Failed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafeApprove(address(token), users.bob, 1);
    }

    function test_fuzz_callSafeApprove_success_whenTrueReturnAndNonZeroValue(address spender, uint256 value) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 1, type(uint256).max);
        MockApproveReturnTrue token = new MockApproveReturnTrue();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafeApprove(address(token), spender, value);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.calls(), 2, "expected token.calls() to equal 2");
        assertEq(token.firstSpender(), spender, "expected token.firstSpender() to equal spender");
        assertEq(token.firstAmount(), 0, "expected token.firstAmount() to equal 0");
        assertEq(token.secondSpender(), spender, "expected token.secondSpender() to equal spender");
        assertEq(token.secondAmount(), value, "expected token.secondAmount() to equal value");
    }

    function test_fuzz_callSafeApprove_success_whenNoReturnDataAndNonZeroValue(address spender, uint256 value)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        value = bound(value, 1, type(uint256).max);
        MockApproveNoReturn token = new MockApproveNoReturn();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafeApprove(address(token), spender, value);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.calls(), 2, "expected token.calls() to equal 2");
        assertEq(token.firstSpender(), spender, "expected token.firstSpender() to equal spender");
        assertEq(token.firstAmount(), 0, "expected token.firstAmount() to equal 0");
        assertEq(token.secondSpender(), spender, "expected token.secondSpender() to equal spender");
        assertEq(token.secondAmount(), value, "expected token.secondAmount() to equal value");
    }

    function test_fuzz_callSafeApprove_success_whenValueIsZero(address spender) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockApproveReturnTrue token = new MockApproveReturnTrue();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callSafeApprove(address(token), spender, 0);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.calls(), 1, "expected token.calls() to equal 1");
        assertEq(token.firstSpender(), spender, "expected token.firstSpender() to equal spender");
        assertEq(token.firstAmount(), 0, "expected token.firstAmount() to equal 0");
        assertEq(token.secondSpender(), address(0), "expected token.secondSpender() to equal address(0)");
        assertEq(token.secondAmount(), 0, "expected token.secondAmount() to equal 0");
    }
}
