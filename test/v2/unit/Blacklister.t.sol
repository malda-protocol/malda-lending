// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Blacklister} from "src/blacklister/Blacklister.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";

import {MockRoles} from "test/mocks/MockRoles.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract BlacklisterTest is BaseTest {
    Blacklister internal blacklister;
    MockRoles internal roles;
    address internal owner;
    address internal guardian;
    address internal user;

    function setUp() public override {
        super.setUp();
        owner = users.admin;
        guardian = users.guardian;
        user = users.alice;

        roles = new MockRoles();
        Blacklister blacklisterImp = new Blacklister();
        bytes memory blacklisterInitData =
            abi.encodeWithSelector(Blacklister.initialize.selector, address(owner), address(roles));
        ERC1967Proxy blacklisterProxy = new ERC1967Proxy(address(blacklisterImp), blacklisterInitData);
        blacklister = Blacklister(address(blacklisterProxy));
        vm.label(address(blacklister), "Blacklister");
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_Blacklister_InvalidRoles() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(owner), address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IBlacklister.Blacklister_InvalidRoles.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new ERC1967Proxy(address(blacklisterImp), initData);
    }

    ////////////////////////////////////////////////////////////
    //                        blacklist                       //
    ////////////////////////////////////////////////////////////

    function test_unit_blacklist_success_emits() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IBlacklister.Blacklisted(user);

        vm.startPrank(owner);
        blacklister.blacklist(user);
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(blacklister.isBlacklisted(user), "expected condition to be true: blacklister.isBlacklisted(user)");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IBlacklister.Unblacklisted(user);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        blacklister.unblacklist(user);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(blacklister.isBlacklisted(user), "expected condition to be false: blacklister.isBlacklisted(user)");
    }

    function test_unit_blacklist_revertsWith_Blacklister_AlreadyBlacklisted() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.startPrank(owner);
        blacklister.blacklist(user);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IBlacklister.Blacklister_AlreadyBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        blacklister.blacklist(user);
        vm.stopPrank();
    }

    function test_unit_blacklist_revertsWith_Blacklister_NotAllowed() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IBlacklister.Blacklister_NotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        blacklister.blacklist(user);
    }

    function test_unit_blacklist_success_whenCalledByGuardian() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        roles.setAllowed(guardian, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IBlacklister.Blacklisted(user);

        vm.startPrank(guardian);
        blacklister.blacklist(user);
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(blacklister.isBlacklisted(user), "expected condition to be true: blacklister.isBlacklisted(user)");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IBlacklister.Unblacklisted(user);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        blacklister.unblacklist(user);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(blacklister.isBlacklisted(user), "expected condition to be false: blacklister.isBlacklisted(user)");
    }

    ////////////////////////////////////////////////////////////
    //                       unblacklist                      //
    ////////////////////////////////////////////////////////////

    function test_unit_unblacklist_revertsWith_Blacklister_NotBlacklisted() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        blacklister.unblacklist(user);
    }

    function test_unit_unblacklist_revertsWith_Blacklister_NotAllowed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        blacklister.blacklist(user);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IBlacklister.Blacklister_NotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        blacklister.unblacklist(user);
    }

    function test_unit_unblacklist_revertsWith_Blacklister_NotBlacklisted_withIndex() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        blacklister.unblacklist(user, 1);
        vm.stopPrank();
    }

    function test_unit_unblacklist_revertsWith_Blacklister_NotBlacklisted_withIndexWithoutEntry() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        blacklister.unblacklist(user, 0);
    }

    ////////////////////////////////////////////////////////////
    //                getBlacklistedAddresses                 //
    ////////////////////////////////////////////////////////////

    function test_unit_getBlacklistedAddresses_success_returnsRemaining() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory list = blacklister.getBlacklistedAddresses();
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(list.length, 1, "expected list.length to equal 1");
        assertEq(list[0], user2, "expected list[0] to equal user2");
    }

    function test_unit_getBlacklistedAddresses_success_handlesIndexRemoval() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory list = blacklister.getBlacklistedAddresses();
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(list.length, 1, "expected list.length to equal 1");
        assertEq(list[0], user2, "expected list[0] to equal user2");
    }

    function test_unit_getBlacklistedAddresses_success_singleEntry() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.startPrank(owner);
        blacklister.blacklist(user);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory list = blacklister.getBlacklistedAddresses();
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(list.length, 1, "expected list.length to equal 1");
        assertEq(list[0], user, "expected list[0] to equal user");
    }

    function test_unit_unblacklist_success_iteratesUntilMatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user2);
        blacklister.blacklist(user);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IBlacklister.Unblacklisted(user);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        blacklister.unblacklist(user);
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(blacklister.isBlacklisted(user), "expected condition to be false: blacklister.isBlacklisted(user)");
    }
}
