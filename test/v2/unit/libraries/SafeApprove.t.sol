// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";
import {MockApproveRevert, MockApproveReturnFalse} from "test/v2/mocks/libraries/SafeApproveMocks.t.sol";

contract SafeApproveHarness {
    using SafeApprove for address;

    function callSafeApprove(address token, address spender, uint256 value) external {
        token.safeApprove(spender, value);
    }
}

contract SafeApproveTest is BaseTest {
    ////////////////////////////////////////////////////////////
    //                       SafeApprove                        //
    ////////////////////////////////////////////////////////////

    function test_unitSafeApprove_revertsWith_revertWhenNoContract() external {
        SafeApproveHarness harness = new SafeApproveHarness();

        vm.expectRevert(SafeApprove.SafeApprove_NoContract.selector);
        harness.callSafeApprove(users.alice, users.bob, 1);
    }

    function test_unitSafeApprove_revertsWith_revertWhenFirstApproveFails() external {
        SafeApproveHarness harness = new SafeApproveHarness();
        MockApproveRevert token = new MockApproveRevert();

        vm.expectRevert(SafeApprove.SafeApprove_Failed.selector);
        harness.callSafeApprove(address(token), users.bob, 1);
    }

    function test_unitSafeApprove_revertsWith_revertWhenSecondApproveReturnsFalse() external {
        SafeApproveHarness harness = new SafeApproveHarness();
        MockApproveReturnFalse token = new MockApproveReturnFalse();

        vm.expectRevert(SafeApprove.SafeApprove_Failed.selector);
        harness.callSafeApprove(address(token), users.bob, 1);
    }
}
