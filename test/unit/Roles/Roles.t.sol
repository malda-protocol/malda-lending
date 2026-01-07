// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {Roles} from "src/Roles.sol";

contract RolesTest is Test {
    Roles internal roles;

    function setUp() public {
        roles = new Roles(address(this));
    }

    function test_allowFor_revertWhenContractZero() external {
        address owner = makeAddr("owner");
        Roles localRoles = new Roles(owner);
        bytes32 pauseManager = localRoles.PAUSE_MANAGER();
        vm.prank(owner);
        vm.expectRevert(IRoles.Roles_InputNotValid.selector);
        localRoles.allowFor(address(0), pauseManager, true);
    }

    function test_allowFor_revertWhenRoleZero() external {
        address owner = makeAddr("owner");
        Roles localRoles = new Roles(owner);
        vm.prank(owner);
        vm.expectRevert(IRoles.Roles_InputNotValid.selector);
        localRoles.allowFor(address(0xBEEF), bytes32(0), true);
    }

    function test_allowFor_setsRole() external {
        Roles localRoles = new Roles(address(this));
        localRoles.allowFor(address(0xBEEF), localRoles.PAUSE_MANAGER(), true);
        assertTrue(localRoles.isAllowedFor(address(0xBEEF), localRoles.PAUSE_MANAGER()));
    }
}
