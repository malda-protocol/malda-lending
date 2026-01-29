// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {Roles} from "src/Roles.sol";

contract RolesTest is BaseTest {
    Roles internal roles;

    function setUp() public override {
        super.setUp();
        roles = new Roles(users.admin);
    }

    ////////////////////////////////////////////////////////////
    //                         AllowFor                         //
    ////////////////////////////////////////////////////////////

    function test_unitAllowFor_revertsWith_revertWhenContractZero() external {
        bytes32 pauseManager = roles.PAUSE_MANAGER();
        vm.prank(users.admin);
        vm.expectRevert(IRoles.Roles_InputNotValid.selector);
        roles.allowFor(address(0), pauseManager, true);
    }

    function test_unitAllowFor_revertsWith_revertWhenRoleZero() external {
        vm.prank(users.admin);
        vm.expectRevert(IRoles.Roles_InputNotValid.selector);
        roles.allowFor(users.alice, bytes32(0), true);
    }

    function test_unitAllowFor_success_setsRole() external {
        bytes32 pauseManager = roles.PAUSE_MANAGER();
        vm.prank(users.admin);
        roles.allowFor(users.alice, pauseManager, true);
        assertTrue(roles.isAllowedFor(users.alice, pauseManager));
    }
}
