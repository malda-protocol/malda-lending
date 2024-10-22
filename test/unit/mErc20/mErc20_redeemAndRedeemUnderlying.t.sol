// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";

// contracts
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";

// tests
import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20_redeem is mToken_Unit_Shared {
    function test_RevertGiven_MarketIsPausedForRdeem(uint256 amount)
        external
        whenPaused(address(mWeth), IRoles.Pause.Redeem)
        whenMarketIsListed(address(mWeth))
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.redeemUnderlying(amount);
    }

    function test_GivenMarketIsNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), IRoles.Pause.Redeem)
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.redeemUnderlying(amount);
    }

    function test_GivenRedeemerIsNotPartOfTheMarket(uint256 amount)
        external
        whenNotPaused(address(mWeth), IRoles.Pause.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWeth))
    {
        _getTokens(weth, address(mWeth), amount);
        vm.expectRevert();
        mWeth.redeem(amount);

        vm.expectRevert();
        mWeth.redeemUnderlying(amount);
    }

    function test_GivenRedeemAmountsAre0()
        external
        whenNotPaused(address(mWeth), IRoles.Pause.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        vm.expectRevert(mTokenStorage.mToken_RedeemEmpty.selector);
        mWeth.redeem(0);
        vm.expectRevert(mTokenStorage.mToken_RedeemEmpty.selector);
        mWeth.redeemUnderlying(0);
    }

    modifier givenAmountIsGreaterThan0() {
        // does nothing; only for readability purposes
        _;
    }

    function test_WhenTheMarketDoesNotHaveEnoughAssetsForTheRedeemOperation(uint256 amount)
        external
        givenAmountIsGreaterThan0
        whenNotPaused(address(mWeth), IRoles.Pause.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWeth))
    {
        // it should revert with mToken_RedeemCashNotAvailable
        vm.expectRevert(mTokenStorage.mToken_RedeemCashNotAvailable.selector);
        mWeth.redeem(amount);

        vm.expectRevert(mTokenStorage.mToken_RedeemCashNotAvailable.selector);
        mWeth.redeemUnderlying(amount);
    }

    function test_WhenStateIsValidForRedeem(uint256 amount)
        external
        givenAmountIsGreaterThan0
        whenNotPaused(address(mWeth), IRoles.Pause.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWeth))
    {
        _redeem(amount, false);
    }

    function test_WhenStateIsValidForRedeemUnderlying(uint256 amount)
        external
        givenAmountIsGreaterThan0
        whenNotPaused(address(mWeth), IRoles.Pause.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWeth))
    {
        _redeem(amount, true);
    }

    function _redeem(uint256 amount, bool underlying) private {
        _borrowPrerequisites(address(mWeth), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 supplyMTokenBefore = mWeth.totalSupply();
        uint256 balanceMTokenBefore = mWeth.balanceOf(address(this));

        amount = amount - DEFAULT_INFLATION_INCREASE;
        if (underlying) mWeth.redeemUnderlying(amount);
        else mWeth.redeem(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 supplyMTokenAfter = mWeth.totalSupply();
        uint256 balanceMTokenAfter = mWeth.balanceOf(address(this));

        // it should transfer underlying to redeemer
        assertEq(balanceWethBefore + amount, balanceWethAfter);

        // it should decrease totalSupply of mToken
        assertGt(supplyMTokenBefore, supplyMTokenAfter);
        assertEq(supplyMTokenBefore - amount, supplyMTokenAfter);

        // it should decrease redeemer balance of mToken
        assertGt(balanceMTokenBefore, balanceMTokenAfter);
        assertEq(balanceMTokenBefore - amount, balanceMTokenAfter);
    }
}
