// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

// contracts
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";

// tests
import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20Host_liquidate is mToken_Unit_Shared {
    function test_RevertGiven_MarketIsPausedForLiquidation(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Liquidate)
        whenMarketIsListed(address(mWethHost))
        inRange(amount, SMALL, LARGE)
        whenImageIdExists
    {
        // it should revert
        bytes memory journalData = _createLiquidationJournal(
            amount,
            address(alice),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Liquidate)
        );

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWethHost.liquidateExternal(journalData, "0x123");
    }

    modifier givenMarketIsNotPaused() {
        _;
    }

    function test_RevertWhen_JournalIsEmpty(uint256 amount)
        external
        givenMarketIsNotPaused
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.repayExternal("", "0x123"); // it should revert
    }

    function test_RevertWhen_JournalIsNonEmptyButLengthIsNotValid(uint256 amount)
        external
        givenMarketIsNotPaused
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        // it should revert
        vm.expectRevert();
        mWethHost.repayExternal("0x", "0x123"); // it should revert
    }

    function test_WhenDecodedAmountIs0() external givenMarketIsNotPaused whenImageIdExists {
        // it should revert with mErc20Host_AmountNotValid

        uint256 amount = 0;
        bytes memory journalData = _createLiquidationJournal(
            amount,
            address(this),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Liquidate)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);
        mWethHost.liquidateExternal(journalData, "0x123");
    }

    modifier whenDecodedAmountIsValid() {
        _;
    }

    function test_RevertWhen_SealVerificationFails(uint256 amount)
        external
        givenMarketIsNotPaused
        whenDecodedAmountIsValid
        whenImageIdExists
        inRange(amount, SMALL, LARGE)
    {
        bytes memory journalData = _createLiquidationJournal(
            amount,
            address(this),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Liquidate)
        );

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethHost.liquidateExternal(journalData, "0x123");
    }

    function test_RevertWhen_UserIsTheSameAsTheLiquidator(uint256 amount)
        external
        givenMarketIsNotPaused
        whenDecodedAmountIsValid
        whenImageIdExists
        inRange(amount, SMALL, LARGE)
    {
        // it should revert
        bytes memory journalData = _createLiquidationJournal(
            amount,
            address(this),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Liquidate)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_CallerNotAllowed.selector);
        mWethHost.liquidateExternal(journalData, "0x123");
    }

    struct LiquidateStateInternal {
        uint256 balanceUnderlyingBefore;
        uint256 balanceMTokenBefore;
        uint256 totalMSupplyBefore;
        uint256 totalBorrowsBefore;
        uint256 accountBorrowBefore;
        uint256 balanceUnderlyingAfter;
        uint256 balanceMTokenAfter;
        uint256 totalMSupplyAfter;
        uint256 totalBorrowsAfter;
        uint256 accountBorrowAfter;
    }

    function test_WhenSealVerificationWasOk(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenImageIdExists
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
        givenMarketIsNotPaused
        whenDecodedAmountIsValid
    {
        LiquidateStateInternal memory vars;
        _repayPrerequisites(address(mWethHost), amount * 2, amount);

        _getTokens(weth, alice, amount * 10);
        vars.balanceUnderlyingBefore = weth.balanceOf(address(alice));
        vars.balanceMTokenBefore = mWethHost.balanceOf(address(alice));
        vars.totalBorrowsBefore = mWethHost.totalBorrows();
        vars.accountBorrowBefore = mWethHost.borrowBalanceStored(address(this));

        bytes memory journalData = _createLiquidationJournal(
            amount,
            alice,
            address(this),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Liquidate)
        );

        operator.setCloseFactor(1e18);
        operator.setLiquidationIncentive(1e17);

        _resetContext(alice);
        mWethHost.liquidateExternal(journalData, "0x123");

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(address(alice));
        vars.balanceMTokenAfter = mWethHost.balanceOf(address(alice));
        vars.totalBorrowsAfter = mWethHost.totalBorrows();
        vars.accountBorrowAfter = mWethHost.borrowBalanceStored(address(this));

        {
            assertEq(vars.balanceUnderlyingBefore, vars.balanceUnderlyingAfter);
            assertGt(vars.balanceMTokenAfter, vars.balanceMTokenBefore);
            assertGt(vars.totalBorrowsBefore, vars.totalBorrowsAfter);
            assertGt(vars.accountBorrowBefore, vars.accountBorrowAfter);
        }
    }

    function test_WhenSealVerificationWasOk_DifferentCollateral(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenImageIdExists
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
        whenMarketIsListed(address(mDaiHost))
        whenMarketEntered(address(mDaiHost))
        givenMarketIsNotPaused
        whenDecodedAmountIsValid
    {
        LiquidateStateInternal memory vars;
        _repayPrerequisites(address(mWethHost), amount * 2, amount);
        _repayPrerequisites(address(mDaiHost), amount * 2, amount);

        vars.balanceUnderlyingBefore = weth.balanceOf(address(alice));
        vars.balanceMTokenBefore = mDaiHost.balanceOf(address(alice));
        vars.totalBorrowsBefore = mWethHost.totalBorrows();
        vars.accountBorrowBefore = mWethHost.borrowBalanceStored(address(this));

        bytes memory journalData = _createLiquidationJournal(
            amount,
            alice,
            address(this),
            address(mDaiHost),
            mWethHost.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Liquidate)
        );

        operator.setCloseFactor(1e18);
        operator.setLiquidationIncentive(1e17);

        _resetContext(alice);
        mWethHost.liquidateExternal(journalData, "0x123");

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(address(alice));
        vars.balanceMTokenAfter = mDaiHost.balanceOf(address(alice));
        vars.totalBorrowsAfter = mWethHost.totalBorrows();
        vars.accountBorrowAfter = mWethHost.borrowBalanceStored(address(this));

        {
            assertEq(vars.balanceUnderlyingBefore, vars.balanceUnderlyingAfter);
            assertGt(vars.balanceMTokenAfter, vars.balanceMTokenBefore);
            assertGt(vars.totalBorrowsBefore, vars.totalBorrowsAfter);
            assertGt(vars.accountBorrowBefore, vars.accountBorrowAfter);
        }
    }
}
