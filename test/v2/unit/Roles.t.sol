// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IRoles} from "src/interfaces/IRoles.sol";
import {Roles} from "src/Roles.sol";

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract RolesTest is BaseTest {
    Roles internal roles;

    function setUp() public override {
        super.setUp();

        roles = new Roles(users.admin);
    }

    ////////////////////////////////////////////////////////////
    //                        allowFor                        //
    ////////////////////////////////////////////////////////////

    function test_fuzz_allowFor_revertsWith_Roles_InputNotValid(bool zeroAddress, bool zeroRole) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(zeroAddress || zeroRole);
        address target = zeroAddress ? address(0) : users.alice;
        bytes32 role = zeroRole ? bytes32(0) : roles.PAUSE_MANAGER();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRoles.Roles_InputNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.admin);
        roles.allowFor(target, role, true);
    }

    function test_unit_allowFor_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes32 pauseManager = roles.PAUSE_MANAGER();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(roles));
        emit Roles.Allowed(users.alice, pauseManager, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.admin);
        roles.allowFor(users.alice, pauseManager, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            roles.isAllowedFor(users.alice, pauseManager),
            "expected condition to be true: roles.isAllowedFor(users.alice, pauseManager)"
        );
    }
}
