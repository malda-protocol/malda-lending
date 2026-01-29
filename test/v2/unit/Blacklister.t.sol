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
    //                 BlacklistAndUnblacklist                  //
    ////////////////////////////////////////////////////////////

    function test_unitBlacklistAndUnblacklist_success() public {
        vm.prank(owner);
        blacklister.blacklist(user);
        assertTrue(blacklister.isBlacklisted(user));

        vm.prank(owner);
        blacklister.unblacklist(user);
        assertFalse(blacklister.isBlacklisted(user));
    }

    ////////////////////////////////////////////////////////////
    //            BlacklistAlreadyBlacklistedReverts            //
    ////////////////////////////////////////////////////////////

    function test_unitBlacklistAlreadyBlacklistedReverts_revertsWith() public {
        vm.startPrank(owner);
        blacklister.blacklist(user);
        vm.expectRevert(IBlacklister.Blacklister_AlreadyBlacklisted.selector);
        blacklister.blacklist(user);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////
    //          BlacklistRevertsForNonOwnerOrGuardian           //
    ////////////////////////////////////////////////////////////

    function test_unitBlacklistRevertsForNonOwnerOrGuardian_revertsWith() public {
        vm.prank(user);
        vm.expectRevert(IBlacklister.Blacklister_NotAllowed.selector);
        blacklister.blacklist(user);
    }

    ////////////////////////////////////////////////////////////
    //            GuardianCanBlacklistAndUnblacklist            //
    ////////////////////////////////////////////////////////////

    function test_unitGuardianCanBlacklistAndUnblacklist_success() public {
        roles.setAllowed(guardian, true);

        vm.prank(guardian);
        blacklister.blacklist(user);
        assertTrue(blacklister.isBlacklisted(user));

        vm.prank(guardian);
        blacklister.unblacklist(user);
        assertFalse(blacklister.isBlacklisted(user));
    }

    ////////////////////////////////////////////////////////////
    //             UnblacklistNotBlacklistedReverts             //
    ////////////////////////////////////////////////////////////

    function test_unitUnblacklistNotBlacklistedReverts_revertsWith() public {
        vm.prank(owner);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user);
    }

    ////////////////////////////////////////////////////////////
    //           UnblacklistRemovesCorrectlyFromArray           //
    ////////////////////////////////////////////////////////////

    function test_unitUnblacklistRemovesCorrectlyFromArray_success() public {
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

    ////////////////////////////////////////////////////////////
    //          UnblacklistSecondUserRemovesCorrectly           //
    ////////////////////////////////////////////////////////////

    function test_unitUnblacklistSecondUserRemovesCorrectly_success() public {
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

    ////////////////////////////////////////////////////////////
    //                 GetBlacklistedAddresses                  //
    ////////////////////////////////////////////////////////////

    function test_unitGetBlacklistedAddresses_success() public {
        vm.startPrank(owner);
        blacklister.blacklist(user);
        address[] memory list = blacklister.getBlacklistedAddresses();
        assertEq(list.length, 1);
        assertEq(list[0], user);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////
    //              UnblacklistByIndexRemovesUser               //
    ////////////////////////////////////////////////////////////

    function test_unitUnblacklistByIndexRemovesUser_success() public {
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
    //           UnblacklistByIndexRevertsOnMismatch            //
    ////////////////////////////////////////////////////////////

    function test_unitUnblacklistByIndexRevertsOnMismatch_revertsWith() public {
        address user2 = users.bob;
        vm.startPrank(owner);
        blacklister.blacklist(user);
        blacklister.blacklist(user2);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user, 1);
        vm.stopPrank();
    }

    ////////////////////////////////////////////////////////////
    //       UnblacklistByIndexRevertsWhenNotBlacklisted        //
    ////////////////////////////////////////////////////////////

    function test_unitUnblacklistByIndexRevertsWhenNotBlacklisted_revertsWith() public {
        vm.prank(owner);
        vm.expectRevert(IBlacklister.Blacklister_NotBlacklisted.selector);
        blacklister.unblacklist(user, 0);
    }

    ////////////////////////////////////////////////////////////
    //              InitializeRevertsWithZeroRoles              //
    ////////////////////////////////////////////////////////////

    function test_unitInitializeRevertsWithZeroRoles_revertsWith() public {
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(owner), address(0));
        vm.expectRevert(IBlacklister.Blacklister_InvalidRoles.selector);
        new ERC1967Proxy(address(blacklisterImp), initData);
    }
}
