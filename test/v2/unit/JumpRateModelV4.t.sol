// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract JumpRateModelV4Test is BaseTest {
    JumpRateModelV4 internal model;
    address internal owner;
    address internal other;

    function setUp() public override {
        super.setUp();
        owner = users.admin;
        other = users.bob;
        model = new JumpRateModelV4(1000, 1e16, 2e16, 3e16, 8e17, owner, "MODEL");
    }

    ////////////////////////////////////////////////////////////
    //                       Getters                          //
    ////////////////////////////////////////////////////////////

    function test_unit_getters_success() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.blocksPerYear(), 1000);
        assertEq(model.baseRatePerBlock(), 1e16);
        assertEq(model.multiplierPerBlock(), 2e16);
        assertEq(model.jumpMultiplierPerBlock(), 3e16);
        assertEq(model.kink(), 8e17);
        assertEq(model.name(), "MODEL");
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenNameEmpty() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        new JumpRateModelV4(1000, 1, 1, 1, 1, owner, "");
    }

    function test_unit_constructor_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenBlocksPerYearZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        new JumpRateModelV4(0, 1, 1, 1, 1, owner, "MODEL");
    }

    ////////////////////////////////////////////////////////////
    //               UpdateJumpRateModelDirect                //
    ////////////////////////////////////////////////////////////

    function test_unit_updateJumpRateModelDirect_revertsWith_OwnableUnauthorizedAccount() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(other);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        model.updateJumpRateModelDirect(1, 1, 1, 1);
    }

    function test_unit_updateJumpRateModelDirect_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenMultiplierZero()
        public
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModelDirect(1, 0, 1, 1);
    }

    function test_unit_updateJumpRateModelDirect_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenJumpMultiplierZero()
        public
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModelDirect(1, 1, 0, 1);
    }

    function test_unit_updateJumpRateModelDirect_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenKinkZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModelDirect(1, 1, 1, 0);
    }

    function test_unit_updateJumpRateModelDirect_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 base = 0;
        uint256 multiplier = 5e16;
        uint256 jump = 7e16;
        uint256 kink = 9e17;

        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.NewInterestParams(base, multiplier, jump, kink);
        model.updateJumpRateModelDirect(base, multiplier, jump, kink);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.baseRatePerBlock(), base);
        assertEq(model.multiplierPerBlock(), multiplier);
        assertEq(model.jumpMultiplierPerBlock(), jump);
        assertEq(model.kink(), kink);
    }

    ////////////////////////////////////////////////////////////
    //                  UpdateJumpRateModel                   //
    ////////////////////////////////////////////////////////////

    function test_unit_updateJumpRateModel_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 baseRatePerYear = 1000;
        uint256 multiplierPerYear = 2000;
        uint256 jumpMultiplierPerYear = 3000;
        uint256 kink = 1e18;

        uint256 expectedBase = baseRatePerYear / model.blocksPerYear();
        uint256 expectedMultiplier = multiplierPerYear * 1e18 / (model.blocksPerYear() * kink);
        uint256 expectedJump = jumpMultiplierPerYear / model.blocksPerYear();

        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.NewInterestParams(expectedBase, expectedMultiplier, expectedJump, kink);
        model.updateJumpRateModel(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.baseRatePerBlock(), expectedBase);
        assertEq(model.multiplierPerBlock(), expectedMultiplier);
        assertEq(model.jumpMultiplierPerBlock(), expectedJump);
        assertEq(model.kink(), kink);
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenBaseRateZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(0, 1, 1, 1);
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenMultiplierZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(1, 0, 1, 1);
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenJumpMultiplierZero()
        public
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(1, 1, 0, 1);
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenKinkZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(1, 1, 1, 0);
    }

    function test_unit_updateJumpRateModel_revertsWith_OwnableUnauthorizedAccount() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(other);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        model.updateJumpRateModel(1, 1, 1, 1);
    }

    ////////////////////////////////////////////////////////////
    //                  updateBlocksPerYear                  //
    ////////////////////////////////////////////////////////////

    function test_unit_updateBlocksPerYear_success(uint256 newBlocksPerYear) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newBlocksPerYear = bound(newBlocksPerYear, 1, 1e12);

        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.BlocksPerYearUpdated(newBlocksPerYear);
        model.updateBlocksPerYear(newBlocksPerYear);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.blocksPerYear(), newBlocksPerYear);
    }

    function test_unit_updateBlocksPerYear_revertsWith_JumpRateModelV4_ZeroValueNotAllowed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(owner);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateBlocksPerYear(0);
    }

    function test_unit_updateBlocksPerYear_revertsWith_OwnableUnauthorizedAccount() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(other);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        model.updateBlocksPerYear(1);
    }

    ////////////////////////////////////////////////////////////
    //                  IsInterestRateModel                   //
    ////////////////////////////////////////////////////////////

    function test_unit_isInterestRateModel_success() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(model.isInterestRateModel());
    }

    ////////////////////////////////////////////////////////////
    //                    UtilizationRate                     //
    ////////////////////////////////////////////////////////////

    function test_unit_utilizationRate_success_zeroBorrows() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.utilizationRate(100, 0, 0), 0);
    }

    function test_unit_utilizationRate_success_cappedAtOne() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 util = model.utilizationRate(10, 90, 50);
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(util, 1e18);
    }

    ////////////////////////////////////////////////////////////
    //                     GetBorrowRate                      //
    ////////////////////////////////////////////////////////////

    function test_unit_getBorrowRate_success_belowKink() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 util = model.utilizationRate(100, 100, 0);
        uint256 expected = util * model.multiplierPerBlock() / 1e18 + model.baseRatePerBlock();
        uint256 rate = model.getBorrowRate(100, 100, 0);
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rate, expected);
    }

    function test_unit_getBorrowRate_success_aboveKink() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 util = model.utilizationRate(1, 9, 0);
        uint256 normalRate = model.kink() * model.multiplierPerBlock() / 1e18 + model.baseRatePerBlock();
        uint256 expected = (util - model.kink()) * model.jumpMultiplierPerBlock() / 1e18 + normalRate;
        uint256 rate = model.getBorrowRate(1, 9, 0);
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rate, expected);
    }

    function test_unit_getBorrowRate_success() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 cash = 100;
        uint256 borrows = 100;
        uint256 reserves = 0;
        uint256 reserveFactor = 2e17;

        uint256 util = model.utilizationRate(cash, borrows, reserves);
        uint256 borrowRate = model.getBorrowRate(cash, borrows, reserves);
        uint256 expected = util * borrowRate * (1e18 - reserveFactor) / 1e36;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.getSupplyRate(cash, borrows, reserves, reserveFactor), expected);
    }
}
