// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";

import {BaseTest} from "test/utils/BaseTest.t.sol";

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
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.blocksPerYear(), 1000, "expected model.blocksPerYear() to equal 1000");
        assertEq(model.baseRatePerBlock(), 1e16, "expected model.baseRatePerBlock() to equal 1e16");
        assertEq(model.multiplierPerBlock(), 2e16, "expected model.multiplierPerBlock() to equal 2e16");
        assertEq(model.jumpMultiplierPerBlock(), 3e16, "expected model.jumpMultiplierPerBlock() to equal 3e16");
        assertEq(model.kink(), 8e17, "expected model.kink() to equal 8e17");
        assertEq(model.name(), "MODEL", "model name does not match expected");
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenNameEmpty() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        new JumpRateModelV4(1000, 1, 1, 1, 1, owner, "");
    }

    function test_unit_constructor_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenBlocksPerYearZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        new JumpRateModelV4(0, 1, 1, 1, 1, owner, "MODEL");
    }

    function test_unit_constructor_success_emits() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 blocksPerYear_ = 900;
        uint256 baseRatePerBlock_ = 3e15;
        uint256 multiplierPerBlock_ = 2e16;
        uint256 jumpMultiplierPerBlock_ = 4e16;
        uint256 kink_ = 85e16;
        string memory name_ = "MODEL_V2";

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.BlocksPerYearUpdated(blocksPerYear_);

        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.NewInterestParams(
            baseRatePerBlock_, multiplierPerBlock_, jumpMultiplierPerBlock_, kink_
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        JumpRateModelV4 newModel = new JumpRateModelV4(
            blocksPerYear_, baseRatePerBlock_, multiplierPerBlock_, jumpMultiplierPerBlock_, kink_, owner, name_
        );

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(newModel.blocksPerYear(), blocksPerYear_, "expected newModel.blocksPerYear() to equal blocksPerYear_");
        assertEq(
            newModel.baseRatePerBlock(),
            baseRatePerBlock_,
            "expected newModel.baseRatePerBlock() to equal baseRatePerBlock_"
        );
        assertEq(
            newModel.multiplierPerBlock(),
            multiplierPerBlock_,
            "expected newModel.multiplierPerBlock() to equal multiplierPerBlock_"
        );
        assertEq(
            newModel.jumpMultiplierPerBlock(),
            jumpMultiplierPerBlock_,
            "expected newModel.jumpMultiplierPerBlock() to equal jumpMultiplierPerBlock_"
        );
        assertEq(newModel.kink(), kink_, "expected newModel.kink() to equal kink_");
        assertEq(newModel.name(), name_, "expected newModel.name() to equal name_");
    }

    ////////////////////////////////////////////////////////////
    //               UpdateJumpRateModelDirect                //
    ////////////////////////////////////////////////////////////

    function test_unit_updateJumpRateModelDirect_revertsWith_OwnableUnauthorizedAccount() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(other);
        model.updateJumpRateModelDirect(1, 1, 1, 1);
    }

    function test_unit_updateJumpRateModelDirect_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenMultiplierZero()
        public
    {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        model.updateJumpRateModelDirect(1, 0, 1, 1);
    }

    function test_unit_updateJumpRateModelDirect_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenJumpMultiplierZero()
        public
    {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        model.updateJumpRateModelDirect(1, 1, 0, 1);
    }

    function test_unit_updateJumpRateModelDirect_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenKinkZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateJumpRateModelDirect(1, 1, 1, 0);
    }

    function test_fuzz_updateJumpRateModelDirect_success(uint256 base, uint256 multiplier, uint256 jump, uint256 kink)
        public
    {
        // Make sure required values are non-zero
        base = bound(base, 0, type(uint256).max);
        multiplier = bound(multiplier, 1, type(uint256).max);
        jump = bound(jump, 1, type(uint256).max);
        kink = bound(kink, 1, type(uint256).max);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.NewInterestParams(base, multiplier, jump, kink);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateJumpRateModelDirect(base, multiplier, jump, kink);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.baseRatePerBlock(), base, "expected model.baseRatePerBlock() to equal base");
        assertEq(model.multiplierPerBlock(), multiplier, "expected model.multiplierPerBlock() to equal multiplier");
        assertEq(model.jumpMultiplierPerBlock(), jump, "expected model.jumpMultiplierPerBlock() to equal jump");
        assertEq(model.kink(), kink, "expected model.kink() to equal kink");
    }

    ////////////////////////////////////////////////////////////
    //                  UpdateJumpRateModel                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_updateJumpRateModel_success(
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink
    ) public {
        // Keep values valid while maximizing exploration range.
        uint256 maxKink = type(uint256).max / model.blocksPerYear();
        baseRatePerYear = bound(baseRatePerYear, 1, type(uint256).max);
        multiplierPerYear = bound(multiplierPerYear, 1, type(uint256).max / 1e18);
        jumpMultiplierPerYear = bound(jumpMultiplierPerYear, 1, type(uint256).max);
        kink = bound(kink, 1, maxKink);

        uint256 expectedBase = baseRatePerYear / model.blocksPerYear();
        uint256 expectedMultiplier = multiplierPerYear * 1e18 / (model.blocksPerYear() * kink);
        uint256 expectedJump = jumpMultiplierPerYear / model.blocksPerYear();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.NewInterestParams(expectedBase, expectedMultiplier, expectedJump, kink);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateJumpRateModel(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.baseRatePerBlock(), expectedBase, "expected model.baseRatePerBlock() to equal expectedBase");
        assertEq(
            model.multiplierPerBlock(),
            expectedMultiplier,
            "expected model.multiplierPerBlock() to equal expectedMultiplier"
        );
        assertEq(
            model.jumpMultiplierPerBlock(),
            expectedJump,
            "expected model.jumpMultiplierPerBlock() to equal expectedJump"
        );
        assertEq(model.kink(), kink, "expected model.kink() to equal kink");
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenBaseRateZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateJumpRateModel(0, 1, 1, 1);
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenMultiplierZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateJumpRateModel(1, 0, 1, 1);
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenJumpMultiplierZero()
        public
    {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        model.updateJumpRateModel(1, 1, 0, 1);
    }

    function test_unit_updateJumpRateModel_revertsWith_JumpRateModelV4_ZeroValueNotAllowed_whenKinkZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateJumpRateModel(1, 1, 1, 0);
    }

    function test_unit_updateJumpRateModel_revertsWith_OwnableUnauthorizedAccount() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(other);
        model.updateJumpRateModel(1, 1, 1, 1);
    }

    ////////////////////////////////////////////////////////////
    //                  updateBlocksPerYear                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_updateBlocksPerYear_success(uint256 newBlocksPerYear) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newBlocksPerYear = bound(newBlocksPerYear, 1, type(uint256).max);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IInterestRateModel.BlocksPerYearUpdated(newBlocksPerYear);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateBlocksPerYear(newBlocksPerYear);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(model.blocksPerYear(), newBlocksPerYear, "expected model.blocksPerYear() to equal newBlocksPerYear");
    }

    function test_unit_updateBlocksPerYear_revertsWith_JumpRateModelV4_ZeroValueNotAllowed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(owner);
        model.updateBlocksPerYear(0);
    }

    function test_unit_updateBlocksPerYear_revertsWith_OwnableUnauthorizedAccount() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(other);
        model.updateBlocksPerYear(1);
    }

    ////////////////////////////////////////////////////////////
    //                  IsInterestRateModel                   //
    ////////////////////////////////////////////////////////////

    function test_unit_isInterestRateModel_success() public view {
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(model.isInterestRateModel(), "expected condition to be true: model.isInterestRateModel()");
    }

    ////////////////////////////////////////////////////////////
    //                    UtilizationRate                     //
    ////////////////////////////////////////////////////////////

    function test_fuzz_utilizationRate_success_zeroBorrows(uint256 cash, uint256 reserves) public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        cash = bound(cash, 0, type(uint256).max);
        reserves = bound(reserves, 0, cash);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            model.utilizationRate(cash, 0, reserves), 0, "expected model.utilizationRate(cash, 0, reserves) to equal 0"
        );
    }

    function test_fuzz_utilizationRate_success_cappedAtOne(uint256 cash, uint256 borrows, uint256 reserves)
        public
        view
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxBorrowsForUtilization = type(uint256).max / 1e18;
        cash = bound(cash, 1, type(uint256).max - maxBorrowsForUtilization);
        borrows = bound(borrows, 2, maxBorrowsForUtilization);
        uint256 maxReserves = cash + borrows - 1;
        reserves = bound(reserves, cash + 1, maxReserves);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 util = model.utilizationRate(cash, borrows, reserves);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(util, 1e18, "expected util to equal 1e18");
    }

    ////////////////////////////////////////////////////////////
    //                     GetBorrowRate                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getBorrowRate_success_belowKink(uint256 cash, uint256 borrows, uint256 reserves) public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxBorrowsForUtilization = type(uint256).max / 1e18;
        borrows = bound(borrows, 1, maxBorrowsForUtilization);
        cash = bound(cash, 0, type(uint256).max - borrows);
        reserves = bound(reserves, 0, cash + borrows - 1);

        uint256 util = model.utilizationRate(cash, borrows, reserves);
        uint256 utilTarget = bound(util, 1, model.kink());
        uint256 principalCash = borrows * 1e18 / utilTarget - borrows;
        uint256 maxReservesForSafeDenominator = type(uint256).max - principalCash - borrows;
        reserves = bound(reserves, 0, maxReservesForSafeDenominator);
        cash = principalCash + reserves;
        util = model.utilizationRate(cash, borrows, reserves);

        uint256 expected = util * model.multiplierPerBlock() / 1e18 + model.baseRatePerBlock();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 rate = model.getBorrowRate(cash, borrows, reserves);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rate, expected, "expected rate to equal expected");
    }

    function test_fuzz_getBorrowRate_success_aboveKink(uint256 cash, uint256 borrows, uint256 reserves) public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxBorrowsForUtilization = type(uint256).max / 1e18;
        borrows = bound(borrows, 1, maxBorrowsForUtilization);
        reserves = bound(reserves, 0, borrows);
        uint256 utilTarget = bound(cash, model.kink() + 1, 1e18);
        cash = (borrows * 1e18 / utilTarget) - borrows + reserves;

        uint256 util = model.utilizationRate(cash, borrows, reserves);
        vm.assume(util > model.kink());

        uint256 normalRate = model.kink() * model.multiplierPerBlock() / 1e18 + model.baseRatePerBlock();
        uint256 expected = (util - model.kink()) * model.jumpMultiplierPerBlock() / 1e18 + normalRate;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 rate = model.getBorrowRate(cash, borrows, reserves);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rate, expected, "expected rate to equal expected");
    }

    function test_fuzz_getBorrowRate_success(uint256 cash, uint256 borrows, uint256 reserves, uint256 reserveFactor)
        public
        view
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxBorrowsForUtilization = type(uint256).max / 1e18;
        borrows = bound(borrows, 1, maxBorrowsForUtilization);
        cash = bound(cash, 0, type(uint256).max - borrows);
        reserves = bound(reserves, 0, cash + borrows - 1);
        reserveFactor = bound(reserveFactor, 0, 1e18);

        uint256 util = model.utilizationRate(cash, borrows, reserves);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 borrowRate = model.getBorrowRate(cash, borrows, reserves);
        uint256 expected = util * borrowRate * (1e18 - reserveFactor) / 1e36;

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            model.getSupplyRate(cash, borrows, reserves, reserveFactor),
            expected,
            "expected model.getSupplyRate(cash, borrows, reserves, reserveFactor) to equal expected"
        );
    }
}
