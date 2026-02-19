// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {Roles} from "src/Roles.sol";

import {BaseTest} from "test/utils/BaseTest.t.sol";

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

    function test_fuzz_allowFor_revertsWith_OwnableUnauthorizedAccount(address unauthorized) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes32 pauseManager = roles.PAUSE_MANAGER();
        vm.assume(unauthorized != address(0));
        vm.assume(unauthorized != roles.owner());

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(unauthorized);
        roles.allowFor(users.bob, pauseManager, true);
    }

    function test_fuzz_allowFor_success(bool isAllowed) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes32 pauseManager = roles.PAUSE_MANAGER();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(roles));
        emit Roles.Allowed(users.alice, pauseManager, isAllowed);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.admin);
        roles.allowFor(users.alice, pauseManager, isAllowed);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            roles.isAllowedFor(users.alice, pauseManager),
            isAllowed,
            "expected roles.isAllowedFor(users.alice, pauseManager) to equal isAllowed"
        );
    }
}
