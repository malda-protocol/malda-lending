// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract ERC20MockTest is BaseTest {
    ERC20Mock internal token;
    address internal admin;
    address internal user;
    address internal pohVerify;
    uint8 internal decimals = 18;
    uint256 internal mintLimit = 1000e18;

    function setUp() public override {
        super.setUp();
        admin = users.admin;
        user = users.alice;
        pohVerify = users.bob;
        token = new ERC20Mock("TestToken", "TTK", decimals, admin, pohVerify, 1000e18);
    }

    ////////////////////////////////////////////////////////////
    //                       MintLimit                        //
    ////////////////////////////////////////////////////////////

    function test_unit_mintLimit_success() public view {
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TTK");
        assertEq(token.decimals(), decimals);
        assertEq(token.admin(), admin);
        assertEq(token.pohVerify(), pohVerify);
        assertEq(token.mintLimit(), mintLimit);
    }

    ////////////////////////////////////////////////////////////
    //                     SetOnlyVerify                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setOnlyVerify_revertsWith_ERC20Mock_NotAuthorized() public {
        vm.prank(user);
        vm.expectRevert(ERC20Mock.ERC20Mock_NotAuthorized.selector);
        token.setOnlyVerify(true);
    }

    function test_unit_setOnlyVerify_success_admin() public {
        vm.prank(admin);
        token.setOnlyVerify(true);
        assertTrue(token.onlyVerified());
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_success_notOnlyVerified_ed() public {
        vm.prank(user);
        token.mint(user, mintLimit - 1);
        assertEq(token.balanceOf(user), mintLimit - 1);
        assertEq(token.minted(user), mintLimit - 1);
    }

    function test_unit_mint_revertsWith_ERC20Mock_AlreadyMinted() public {
        vm.prank(user);
        token.mint(user, mintLimit - 1);
        vm.prank(user);
        vm.expectRevert(ERC20Mock.ERC20Mock_AlreadyMinted.selector);
        token.mint(user, 2);
    }

    ////////////////////////////////////////////////////////////
    //                          Burn                          //
    ////////////////////////////////////////////////////////////

    function test_unit_burn_success_success() public {
        vm.prank(user);
        token.mint(user, 500);
        vm.prank(user);
        token.burn(300);
        assertEq(token.balanceOf(user), 200);
        assertEq(token.minted(user), 500);
    }

    function test_unit_burn_revertsWith_ERC20Mock_TooMuch() public {
        vm.prank(user);
        token.mint(user, 500);
        vm.prank(user);
        vm.expectRevert(ERC20Mock.ERC20Mock_TooMuch.selector);
        token.burn(600);
    }

    function test_unit_burn_success_admin() public {
        vm.prank(user);
        token.mint(user, 500);
        vm.prank(admin);
        token.burn(user, 300);
        assertEq(token.balanceOf(user), 200);
        assertEq(token.minted(user), 500);
    }

    function test_unit_burn_revertsWith_ERC20Mock_NotAuthorized_from() public {
        vm.prank(user);
        token.mint(user, 500);
        vm.prank(user);
        vm.expectRevert(ERC20Mock.ERC20Mock_NotAuthorized.selector);
        token.burn(admin, 100);
    }
}
