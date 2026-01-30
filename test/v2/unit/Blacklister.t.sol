// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Blacklister} from "src/blacklister/Blacklister.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";

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
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_Blacklister_InvalidRoles() public {
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(owner), address(0));
        vm.expectRevert(IBlacklister.Blacklister_InvalidRoles.selector);
        new ERC1967Proxy(address(blacklisterImp), initData);
    }

    ////////////////////////////////////////////////////////////
    //                       Blacklist                        //
    ////////////////////////////////////////////////////////////

    function test_unit_blacklist_success() public {
        vm.prank(owner);
        blacklister.blacklist(user);
        assertTrue(blacklister.isBlacklisted(user));

        vm.prank(owner);
        blacklister.unblacklist(user);
        assertFalse(blacklister.isBlacklisted(user));
    }

    function test_unit_blacklist_revertsWith_Blacklister_AlreadyBlacklisted() public {
        vm.startPrank(owner);
        blacklister.blacklist(user);
        vm.expectRevert(IBlacklister.Blacklister_AlreadyBlacklisted.selector);
        blacklister.blacklist(user);
        vm.stopPrank();
    }

    function test_unit_blacklist_revertsWith_Blacklister_NotAllowed() public {
        vm.prank(user);
        vm.expectRevert(IBlacklister.Blacklister_NotAllowed.selector);
        blacklister.blacklist(user);
    }

    function test_unit_blacklist_success_whenCalledByGuardian() public {
        roles.setAllowed(guardian, true);

        vm.prank(guardian);
        blacklister.blacklist(user);
        assertTrue(blacklister.isBlacklisted(user));

        vm.prank(guardian);
        blacklister.unblacklist(user);
        assertFalse(blacklister.isBlacklisted(user));
    }

    ////////////////////////////////////////////////////////////
    //                      Unblacklist                       //
    ////////////////////////////////////////////////////////////

    function test_unit_unblacklist_revertsWith_Blacklister_NotBlacklisted() public {
        vm.prank(owner);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user);
    }

    ////////////////////////////////////////////////////////////
    //                GetBlacklistedAddresses                 //
    ////////////////////////////////////////////////////////////

    function test_unit_getBlacklistedAddresses_success_variant1() public {
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user2);
        vm.stopPrank();
    }

    function test_unit_getBlacklistedAddresses_success_variant2() public {
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user2);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user);
        vm.stopPrank();
    }

    function test_unit_getBlacklistedAddresses_success_variant3() public {
        vm.startPrank(owner);
        blacklister.blacklist(user);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user);
        vm.stopPrank();
    }

    function test_unit_getBlacklistedAddresses_success_variant4() public {
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        blacklister.unblacklist(user, 0);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user2);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////
    //                      Unblacklist                       //
    ////////////////////////////////////////////////////////////

    function test_unit_unblacklist_revertsWith_Blacklister_NotBlacklisted_byIndex() public {
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user, 1);
        vm.stopPrank();
    }

    function test_unit_unblacklist_revertsWith_Blacklister_NotBlacklisted_withoutIndex() public {
        vm.prank(owner);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user, 0);
    }
}
