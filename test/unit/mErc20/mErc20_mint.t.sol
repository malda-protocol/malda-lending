// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

// contracts
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";

// tests
import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20_mint is mToken_Unit_Shared {
    function test_RevertGiven_MarketIsPausedForMinting(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Mint)
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.mint(amount);
    }

    function test_RevertGiven_MarketIsNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Mint)
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.mint(amount);
    }

    function test_RevertGiven_WhenSupplyCapIsReached(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenSupplyCapReached(address(mWeth), amount)
        whenMarketIsListed(address(mWeth))
    {
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        // it should revert with Operator_MarketSupplyReached
        vm.expectRevert(OperatorStorage.Operator_MarketSupplyReached.selector);
        mWeth.mint(amount);
    }

    function test_WhenSupplyCapIsGreater(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWeth))
    {
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWeth.totalSupply();
        uint256 balanceOfBefore = mWeth.balanceOf(address(this));

        mWeth.mint(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWeth.totalSupply();
        uint256 balanceOfAfter = mWeth.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore);

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore);

        // it should transfer underlying from user
        assertGt(balanceWethBefore, balanceWethAfter);

        assertEq(totalSupplyAfter - amount, totalSupplyBefore);
    }

    function test_GivenAmountIs0() external whenMarketIsListed(address(mWeth)) {
        uint256 amount = ZERO_VALUE;
        vm.expectRevert(); //arithmetic underflow or overflow
        mWeth.mint(amount);
    }
}
