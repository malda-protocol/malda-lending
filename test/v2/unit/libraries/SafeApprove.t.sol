// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SafeApprove} from "src/libraries/SafeApprove.sol";

import {MockApproveRevert, MockApproveReturnFalse} from "test/v2/mocks/libraries/SafeApproveMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract SafeApproveHarness {
    using SafeApprove for address;

    function callSafeApprove(address token, address spender, uint256 value) external {
        token.safeApprove(spender, value);
    }
}

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
}
