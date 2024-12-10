// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_outHere is mToken_Unit_Shared {
    function test_RevertGiven_IsPaused(uint256 amount) external inRange(amount, SMALL, LARGE) {
        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountOutHere, true);

        vm.expectRevert();
        mWethExtension.outHere("", "0x123", amount);
    }

    modifier givenMarketIsNotPaused() {
        _;
    }

    function test_RevertWhen_AmountIs(uint256 amount) external inRange(amount, SMALL, LARGE) givenMarketIsNotPaused {
        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(this), amount, 0);

        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.outHere(journalData, "0x123", 0);
    }

    function test_WhenAccumulatedAmountReceivedOrLessThanNeeded(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenMarketIsNotPaused
    {
        // it should revert with mTokenGateway_AmountTooBig
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(this), amount - 1, 0);
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountTooBig.selector);
        mWethExtension.outHere(journalData, "0x123", amount);
    }

    function test_WhenMarketDoesNotHaveLiquidity(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenMarketIsNotPaused
    {
        // it should revert with mTokenGateway_ReleaseCashNotAvailable
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(this), amount, 0);
        vm.expectRevert(ImTokenGateway.mTokenGateway_ReleaseCashNotAvailable.selector);
        mWethExtension.outHere(journalData, "0x123", amount);
    }

    function test_RevertWhen_CallerNotAllowedXQ(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenMarketIsNotPaused
    {
        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(this), amount, 0);
        _resetContext(alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.outHere(journalData, "0x123", amount);
    }

    function test_WhenParametersAreRight(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenMarketIsNotPaused
    {
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), alice, amount, 0);

        _getTokens(weth, address(mWethExtension), amount);

        uint256 balanceUserBefore = weth.balanceOf(alice);
        mWethExtension.outHere(journalData, "0x123", amount);
        uint256 balanceUserAfter = weth.balanceOf(alice);

        // it should increase nonce
        assertEq(mWethExtension.nonce(), 1);

        // it should increase accAmountOut
        assertEq(mWethExtension.accAmountOut(address(this)), amount);

        // it should transfer underlying to user
        assertEq(balanceUserBefore + amount, balanceUserAfter);
    }

    function test_WhenParametersAreRightDifferentUsersQE(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenMarketIsNotPaused
    {
        address[] memory allowerdCallers = new address[](1);
        allowerdCallers[0] = alice;
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), alice, amount, 0, allowerdCallers);

        _getTokens(weth, address(mWethExtension), amount);

        uint256 balanceUserBefore = weth.balanceOf(alice);
        _resetContext(alice);
        mWethExtension.outHere(journalData, "0x123", amount);
        uint256 balanceUserAfter = weth.balanceOf(alice);

        // it should increase nonce
        assertEq(mWethExtension.nonce(), 1);

        // it should increase accAmountOut
        assertEq(mWethExtension.accAmountOut(address(this)), amount);

        // it should transfer underlying to user
        assertEq(balanceUserBefore + amount, balanceUserAfter);
    }
}
