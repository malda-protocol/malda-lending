// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";

contract BatchSubmitter_constructor is Test {
    function test_RevertWhen_RolesZero() external {
        vm.expectRevert(BatchSubmitter.BatchSubmitter_AddressNotValid.selector);
        new BatchSubmitter(address(0), address(1), address(this));
    }

    function test_RevertWhen_ZkVerifierZero() external {
        vm.expectRevert(BatchSubmitter.BatchSubmitter_AddressNotValid.selector);
        new BatchSubmitter(address(1), address(0), address(this));
    }
}
