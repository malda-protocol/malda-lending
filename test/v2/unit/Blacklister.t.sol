// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Blacklister} from "src/blacklister/Blacklister.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";

contract BlacklisterTest is Test {
    Blacklister internal blacklister;
    MockRoles internal roles;
    address internal owner = address(0xABCD);
    address internal guardian = address(0xBEEF);
    address internal user = address(0xCAFE);

    function setUp() public {
        roles = new MockRoles();
        Blacklister blacklisterImp = new Blacklister();
        bytes memory blacklisterInitData =
            abi.encodeWithSelector(Blacklister.initialize.selector, address(owner), address(roles));
        ERC1967Proxy blacklisterProxy = new ERC1967Proxy(address(blacklisterImp), blacklisterInitData);
        blacklister = Blacklister(address(blacklisterProxy));
        vm.label(address(blacklister), "Blacklister");
    }

    function testBlacklistAndUnblacklist() public {
        vm.prank(owner);
        blacklister.blacklist(user);
        assertTrue(blacklister.isBlacklisted(user));

        vm.prank(owner);
        blacklister.unblacklist(user);
        assertFalse(blacklister.isBlacklisted(user));
    }

    function testBlacklistAlreadyBlacklistedReverts() public {
        vm.startPrank(owner);
        blacklister.blacklist(user);
        vm.expectRevert(IBlacklister.Blacklister_AlreadyBlacklisted.selector);
        blacklister.blacklist(user);
        vm.stopPrank();
    }

    function testBlacklistRevertsForNonOwnerOrGuardian() public {
        vm.prank(user);
        vm.expectRevert(IBlacklister.Blacklister_NotAllowed.selector);
        blacklister.blacklist(user);
    }

    function testGuardianCanBlacklistAndUnblacklist() public {
        roles.setAllowed(guardian, true);

        vm.prank(guardian);
        blacklister.blacklist(user);
        assertTrue(blacklister.isBlacklisted(user));

        vm.prank(guardian);
        blacklister.unblacklist(user);
        assertFalse(blacklister.isBlacklisted(user));
    }

    function testUnblacklistNotBlacklistedReverts() public {
        vm.prank(owner);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user);
    }

    function testUnblacklistRemovesCorrectlyFromArray() public {
        address user2 = address(0xDEAD);
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user2);
        vm.stopPrank();
    }

    function testUnblacklistSecondUserRemovesCorrectly() public {
        address user2 = address(0xDEAD);
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user2);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user);
        vm.stopPrank();
    }

    function testGetBlacklistedAddresses() public {
        vm.startPrank(owner);
        blacklister.blacklist(user);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user);
        vm.stopPrank();
    }

    function testUnblacklistByIndexRemovesUser() public {
        address user2 = address(0xDEAD);
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user, 0);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user2);
        vm.stopPrank();
    }

    function testUnblacklistByIndexRevertsOnMismatch() public {
        address user2 = address(0xDEAD);
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user, 1);
        vm.stopPrank();
    }

    function testUnblacklistByIndexRevertsWhenNotBlacklisted() public {
        vm.prank(owner);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user, 0);
    }

    function testInitializeRevertsWithZeroRoles() public {
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(owner), address(0));
        vm.expectRevert(IBlacklister.Blacklister_InvalidRoles.selector);
        new ERC1967Proxy(address(blacklisterImp), initData);
    }
}
