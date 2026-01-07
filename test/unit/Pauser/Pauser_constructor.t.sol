// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {Pauser} from "src/pauser/Pauser.sol";
import {IPauser} from "src/interfaces/IPauser.sol";

contract Pauser_constructor is Test {
    function test_RevertWhen_RolesIsZero() external {
        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);
        new Pauser(address(0), address(1), address(this));
    }

    function test_RevertWhen_OperatorIsZero() external {
        vm.expectRevert(IPauser.Pauser_AddressNotValid.selector);
        new Pauser(address(1), address(0), address(this));
    }
}
