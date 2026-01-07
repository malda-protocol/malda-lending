// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract JumpRateModelV4Test is Test {
    event NewInterestParams(
        uint256 baseRatePerBlock, uint256 multiplierPerBlock, uint256 jumpMultiplierPerBlock, uint256 kink
    );
    event BlocksPerYearUpdated(uint256 blocksPerYear);

    JumpRateModelV4 internal model;
    address internal owner;
    address internal other;

    function setUp() public {
        owner = address(this);
        other = vm.addr(77);
        model = new JumpRateModelV4(1000, 1e16, 2e16, 3e16, 8e17, owner, "MODEL");
    }

    function test_Constructor_SetsState() public view {
        assertEq(model.blocksPerYear(), 1000);
        assertEq(model.baseRatePerBlock(), 1e16);
        assertEq(model.multiplierPerBlock(), 2e16);
        assertEq(model.jumpMultiplierPerBlock(), 3e16);
        assertEq(model.kink(), 8e17);
        assertEq(model.name(), "MODEL");
    }

    function test_Constructor_RevertWhenNameEmpty() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        new JumpRateModelV4(1000, 1, 1, 1, 1, owner, "");
    }

    function test_Constructor_RevertWhenBlocksPerYearZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        new JumpRateModelV4(0, 1, 1, 1, 1, owner, "MODEL");
    }

    function test_UpdateJumpRateModelDirect_Updates() public {
        uint256 base = 0;
        uint256 multiplier = 5e16;
        uint256 jump = 7e16;
        uint256 kink = 9e17;

        vm.expectEmit(false, false, false, true);
        emit NewInterestParams(base, multiplier, jump, kink);
        model.updateJumpRateModelDirect(base, multiplier, jump, kink);

        assertEq(model.baseRatePerBlock(), base);
        assertEq(model.multiplierPerBlock(), multiplier);
        assertEq(model.jumpMultiplierPerBlock(), jump);
        assertEq(model.kink(), kink);
    }

    function test_UpdateJumpRateModelDirect_RevertWhenNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        model.updateJumpRateModelDirect(1, 1, 1, 1);
    }

    function test_UpdateJumpRateModelDirect_RevertWhenMultiplierZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModelDirect(1, 0, 1, 1);
    }

    function test_UpdateJumpRateModelDirect_RevertWhenJumpMultiplierZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModelDirect(1, 1, 0, 1);
    }

    function test_UpdateJumpRateModelDirect_RevertWhenKinkZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModelDirect(1, 1, 1, 0);
    }

    function test_UpdateJumpRateModel_Updates() public {
        uint256 baseRatePerYear = 1000;
        uint256 multiplierPerYear = 2000;
        uint256 jumpMultiplierPerYear = 3000;
        uint256 kink = 1e18;

        uint256 expectedBase = baseRatePerYear / model.blocksPerYear();
        uint256 expectedMultiplier = multiplierPerYear * 1e18 / (model.blocksPerYear() * kink);
        uint256 expectedJump = jumpMultiplierPerYear / model.blocksPerYear();

        vm.expectEmit(false, false, false, true);
        emit NewInterestParams(expectedBase, expectedMultiplier, expectedJump, kink);
        model.updateJumpRateModel(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink);

        assertEq(model.baseRatePerBlock(), expectedBase);
        assertEq(model.multiplierPerBlock(), expectedMultiplier);
        assertEq(model.jumpMultiplierPerBlock(), expectedJump);
        assertEq(model.kink(), kink);
    }

    function test_UpdateJumpRateModel_RevertWhenBaseRateZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(0, 1, 1, 1);
    }

    function test_UpdateJumpRateModel_RevertWhenMultiplierZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(1, 0, 1, 1);
    }

    function test_UpdateJumpRateModel_RevertWhenJumpMultiplierZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(1, 1, 0, 1);
    }

    function test_UpdateJumpRateModel_RevertWhenKinkZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateJumpRateModel(1, 1, 1, 0);
    }

    function test_UpdateJumpRateModel_RevertWhenNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        model.updateJumpRateModel(1, 1, 1, 1);
    }

    function test_UpdateBlocksPerYear_Updates(uint256 newBlocksPerYear) public {
        newBlocksPerYear = bound(newBlocksPerYear, 1, 1e12);

        vm.expectEmit(false, false, false, true);
        emit BlocksPerYearUpdated(newBlocksPerYear);
        model.updateBlocksPerYear(newBlocksPerYear);

        assertEq(model.blocksPerYear(), newBlocksPerYear);
    }

    function test_UpdateBlocksPerYear_RevertWhenZero() public {
        vm.expectRevert(IInterestRateModel.JumpRateModelV4_ZeroValueNotAllowed.selector);
        model.updateBlocksPerYear(0);
    }

    function test_UpdateBlocksPerYear_RevertWhenNotOwner() public {
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, other));
        model.updateBlocksPerYear(1);
    }

    function test_IsInterestRateModel() public view {
        assertTrue(model.isInterestRateModel());
    }

    function test_UtilizationRate_ZeroBorrows() public view {
        assertEq(model.utilizationRate(100, 0, 0), 0);
    }

    function test_UtilizationRate_CappedAtOne() public view {
        uint256 util = model.utilizationRate(10, 90, 50);
        assertEq(util, 1e18);
    }

    function test_GetBorrowRate_BelowKink() public view {
        uint256 util = model.utilizationRate(100, 100, 0);
        uint256 expected = util * model.multiplierPerBlock() / 1e18 + model.baseRatePerBlock();
        uint256 rate = model.getBorrowRate(100, 100, 0);
        assertEq(rate, expected);
    }

    function test_GetBorrowRate_AboveKink() public view {
        uint256 util = model.utilizationRate(1, 9, 0);
        uint256 normalRate = model.kink() * model.multiplierPerBlock() / 1e18 + model.baseRatePerBlock();
        uint256 expected = (util - model.kink()) * model.jumpMultiplierPerBlock() / 1e18 + normalRate;
        uint256 rate = model.getBorrowRate(1, 9, 0);
        assertEq(rate, expected);
    }

    function test_GetSupplyRate() public view {
        uint256 cash = 100;
        uint256 borrows = 100;
        uint256 reserves = 0;
        uint256 reserveFactor = 2e17;

        uint256 util = model.utilizationRate(cash, borrows, reserves);
        uint256 borrowRate = model.getBorrowRate(cash, borrows, reserves);
        uint256 expected = util * borrowRate * (1e18 - reserveFactor) / 1e36;

        assertEq(model.getSupplyRate(cash, borrows, reserves, reserveFactor), expected);
    }
}
