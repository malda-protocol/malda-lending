// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// interfaces
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

// contracts
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";

// tests
import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20Host_liquidate is mToken_Unit_Shared {
    function setUp() public virtual override {
        super.setUp();

        mWethHost.updateAllowedChain(uint32(block.chainid), true);
    }

    function test_RevertGiven_MarketIsPausedForLiquidation(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Liquidate)
        whenMarketIsListed(address(mWethHost))
        inRange(amount, SMALL, LARGE)
    {
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory users = new address[](1);
        users[0] = alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWethHost.liquidateExternal(journalData, "0x123", users, amounts, collaterals);
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
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory users = new address[](1);
        users[0] = alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.liquidateExternal("", "0x123", users, amounts, collaterals);
    }

    function test_RevertWhen_JournalIsNonEmptyButLengthIsNotValid(uint256 amount)
        external
        givenMarketIsNotPaused
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory users = new address[](1);
        users[0] = alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        vm.expectRevert();
        mWethHost.liquidateExternal("0x", "0x123", users, amounts, collaterals);
    }

    function test_WhenDecodedAmountIs0() external givenMarketIsNotPaused {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        address[] memory users = new address[](1);
        users[0] = alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), 0);

        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);
        mWethHost.liquidateExternal(journalData, "0x123", users, amounts, collaterals);
    }

    modifier whenDecodedAmountIsValid() {
        _;
    }

    function test_RevertWhen_SealVerificationFails(uint256 amount)
        external
        givenMarketIsNotPaused
        whenDecodedAmountIsValid
        inRange(amount, SMALL, LARGE)
    {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory users = new address[](1);
        users[0] = alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethHost.liquidateExternal(journalData, "0x123", users, amounts, collaterals);
    }

    function test_RevertWhen_UserIsTheSameAsTheLiquidator(uint256 amount)
        external
        givenMarketIsNotPaused
        whenDecodedAmountIsValid
        inRange(amount, SMALL, LARGE)
    {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory users = new address[](1);
        users[0] = alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        bytes memory journalData = _createAccumulatedAmountJournal(alice, address(mWethHost), amount);

        vm.expectRevert(ImErc20Host.mErc20Host_CallerNotAllowed.selector);
        mWethHost.liquidateExternal(journalData, "0x123", users, amounts, collaterals);
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

    function test_WhenSealVerificationWasOkQA(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
        givenMarketIsNotPaused
        whenDecodedAmountIsValid
    {
        mWethHost.setRolesOperator(address(roles));

        LiquidateStateInternal memory vars;
        _repayPrerequisites(address(mWethHost), amount * 2, amount);

        _getTokens(weth, alice, amount * 10);
        vars.balanceUnderlyingBefore = weth.balanceOf(address(bob));
        vars.balanceMTokenBefore = mWethHost.balanceOf(address(bob));
        vars.totalBorrowsBefore = mWethHost.totalBorrows();
        vars.accountBorrowBefore = mWethHost.borrowBalanceStored(address(this));

        bytes memory journalData = _createAccumulatedAmountJournal(bob, address(mWethHost), amount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory users = new address[](1);
        users[0] = address(this);
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        operator.setCloseFactor(1e18);
        operator.setLiquidationIncentive(1e17);

        _resetContext(bob);
        mWethHost.updateAllowedCallerStatus(alice, true);

        _resetContext(alice);
        mWethHost.liquidateExternal(journalData, "0x123", users, amounts, collaterals);

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(address(bob));
        vars.balanceMTokenAfter = mWethHost.balanceOf(address(bob));
        vars.totalBorrowsAfter = mWethHost.totalBorrows();
        vars.accountBorrowAfter = mWethHost.borrowBalanceStored(address(this));

        {
            assertEq(vars.balanceUnderlyingBefore, vars.balanceUnderlyingAfter);
            assertGt(vars.balanceMTokenAfter, vars.balanceMTokenBefore);
            assertGt(vars.totalBorrowsBefore, vars.totalBorrowsAfter);
            assertGt(vars.accountBorrowBefore, vars.accountBorrowAfter);
        }
    }

    /**
     * function test_WhenSealVerificationWasOk_DifferentCollateral(uint256 amount)
     *     external
     *     inRange(amount, SMALL, LARGE)
     *     whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
     *     whenMarketIsListed(address(mWethHost))
     *     whenMarketEntered(address(mWethHost))
     *     whenMarketIsListed(address(mDaiHost))
     *     givenMarketIsNotPaused
     *     whenDecodedAmountIsValid
     * {
     *     // didn't use a modifier because of stack too dep
     *     {
     *         address[] memory mTokens = new address[](1);
     *         mTokens[0] = address(mDaiHost);
     *         operator.enterMarkets(mTokens);
     *         operator.setCollateralFactor(mTokens[0], DEFAULT_COLLATERAL_FACTOR);
     *     }
     *     _repayPrerequisites(address(mWethHost), amount * 2, amount);
     *     _repayPrerequisites(address(mDaiHost), amount * 2, amount);
     *
     *     mWethHost.setRolesOperator(address(roles));
     *
     *     LiquidateStateInternal memory vars;
     *     vars.balanceMTokenBefore = mDaiHost.balanceOf(address(alice));
     *
     *     bytes memory journalData = _createAccumulatedAmountJournal(alice, address(mWethHost), amount);
     *
     *     operator.setCloseFactor(1e18);
     *     operator.setLiquidationIncentive(1e17);
     *
     *     _resetContext(alice);
     *     mWethHost.liquidateExternal(journalData, "0x123", address(this), address(this), amount, address(mDaiHost));
     *
     *     // after state
     *     vars.balanceMTokenAfter = mDaiHost.balanceOf(address(alice));
     *
     *     {
     *         assertGt(vars.balanceMTokenAfter, vars.balanceMTokenBefore);
     *     }
     * }
     */
}
