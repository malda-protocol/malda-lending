// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

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
        token = new ERC20Mock("TestToken", "TTK", decimals, admin, pohVerify, mintLimit);
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_success_setsMetadata() external view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TTK");
        assertEq(token.decimals(), decimals);
        assertEq(token.admin(), admin);
        assertEq(token.pohVerify(), pohVerify);
        assertEq(token.mintLimit(), mintLimit);
    }

    ////////////////////////////////////////////////////////////
    //                     setOnlyVerify                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setOnlyVerify_revertsWith_ERC20Mock_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ERC20Mock.ERC20Mock_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.setOnlyVerify(true);
    }

    function test_unit_setOnlyVerify_success_admin() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        token.setOnlyVerify(true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(token.onlyVerified());
    }

    ////////////////////////////////////////////////////////////
    //                          mint                          //
    ////////////////////////////////////////////////////////////

    function test_fuzz_mint_success_whenNotOnlyVerified(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 1, mintLimit - 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(address(0), user, amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, amount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(user), amount);
        assertEq(token.minted(user), amount);
    }

    function test_unit_mint_revertsWith_ERC20Mock_OnlyVerified() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(admin);
        token.setOnlyVerify(true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ERC20Mock.ERC20Mock_OnlyVerified.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, mintLimit - 1);
    }

    function test_unit_mint_revertsWith_ERC20Mock_AlreadyMinted() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, mintLimit - 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ERC20Mock.ERC20Mock_AlreadyMinted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, 2);
    }

    ////////////////////////////////////////////////////////////
    //                          burn                          //
    ////////////////////////////////////////////////////////////

    function test_unit_burn_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, 500);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(user, address(0), 300);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.burn(300);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(user), 200);
        assertEq(token.minted(user), 500);
    }

    function test_unit_burn_revertsWith_ERC20Mock_TooMuch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, 500);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ERC20Mock.ERC20Mock_TooMuch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.burn(600);
    }

    function test_unit_burn_success_admin() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, 500);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(user, address(0), 300);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(admin);
        token.burn(user, 300);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(user), 200);
        assertEq(token.minted(user), 500);
    }

    function test_unit_burn_revertsWith_ERC20Mock_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(user);
        token.mint(user, 500);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ERC20Mock.ERC20Mock_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        token.burn(admin, 100);
    }
}
