// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";

contract SafeApproveHarness {
    using SafeApprove for address;

    function callSafeApprove(address token, address spender, uint256 value) external {
        token.safeApprove(spender, value);
    }
}

contract MockApproveRevert {
    function approve(address, uint256) external pure returns (bool) {
        revert("APPROVE_REVERT");
    }
}

contract MockApproveReturnFalse {
    function approve(address, uint256 amount) external pure returns (bool) {
        return amount == 0;
    }
}

contract SafeApproveTest is Test {
    function testSafeApprove_revertWhenNoContract() external {
        SafeApproveHarness harness = new SafeApproveHarness();

        vm.expectRevert(SafeApprove.SafeApprove_NoContract.selector);
        harness.callSafeApprove(address(0x1234), address(0xBEEF), 1);
    }

    function testSafeApprove_revertWhenFirstApproveFails() external {
        SafeApproveHarness harness = new SafeApproveHarness();
        MockApproveRevert token = new MockApproveRevert();

        vm.expectRevert(SafeApprove.SafeApprove_Failed.selector);
        harness.callSafeApprove(address(token), address(0xBEEF), 1);
    }

    function testSafeApprove_revertWhenSecondApproveReturnsFalse() external {
        SafeApproveHarness harness = new SafeApproveHarness();
        MockApproveReturnFalse token = new MockApproveReturnFalse();

        vm.expectRevert(SafeApprove.SafeApprove_Failed.selector);
        harness.callSafeApprove(address(token), address(0xBEEF), 1);
    }
}
