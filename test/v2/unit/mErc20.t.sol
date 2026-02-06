// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOperator} from "src/interfaces/IOperator.sol";
import {ImToken, ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";
import {mErc20} from "src/mToken/mErc20.sol";
import {mErc20Immutable} from "src/mToken/mErc20Immutable.sol";
import {mErc20Upgradable} from "src/mToken/mErc20Upgradable.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {LiquidationHelper} from "src/utils/LiquidationHelper.sol";
import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";

import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";

contract mErc20UpgradableHarnessV2 is mErc20Upgradable {
    function initializeHarness(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_,
        address payable admin_
    ) external {
        _proxyInitialize(
            underlying_, operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_, admin_
        );
    }
}

contract mErc20Test is BaseMTokenTest {
    mErc20UpgradableHarnessV2 internal harness;
    uint256 internal constant EXP_SCALE = 1e18;

    function setUp() public override {
        super.setUp();

        harness = new mErc20UpgradableHarnessV2();
        helper = new LiquidationHelper();
        vm.label(address(helper), "LiquidationHelper");
        borrower = users.alice;
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_mErc20Immutable_AdminNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mErc20Immutable.mErc20Immutable_AdminNotValid.selector);
        new mErc20Immutable(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(0))
        );
    }

    ////////////////////////////////////////////////////////////
    //                   InitializeHarness                    //
    ////////////////////////////////////////////////////////////

    function test_unit_initializeHarness_revertsWith_mErc20Upgradable_AdminNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mErc20Upgradable.mErc20Upgradable_AdminNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(0))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_AddressNotValid_whenUnderlyingZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(0),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_AddressNotValid_whenOperatorZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth), address(0), address(interestModel), 1e18, "Market WETH", "mWeth", 18, payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_AddressNotValid_whenInterestModelZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth), address(operator), address(0), 1e18, "Market WETH", "mWeth", 18, payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_NameNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_NameNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth), address(operator), address(interestModel), 1e18, "", "mWeth", 18, payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_SymbolNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_SymbolNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "",
            18,
            payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_DecimalsNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_DecimalsNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            0,
            payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_ExchangeRateNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_ExchangeRateNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            0,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_AlreadyInitialized() external {
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_AlreadyInitialized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );
    }

    ////////////////////////////////////////////////////////////
    //                         Borrow                         //
    ////////////////////////////////////////////////////////////

    function test_unit_borrow_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_EmptyPrice_revertGiven(uint256 amount)
        external
        whenPriceIs(ZERO_VALUE)
        whenUnderlyingPriceIs(ZERO_VALUE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mt_BorrowCashNotAvailable but it actually reverts with InsufficientLiquidity for non cross-chain tokens
        // cannot test this in a non-external flow

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_mt_BorrowCashNotAvailable()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));
        operator.supportMarket(address(mDaiHost));
        operator.setCollateralFactor(address(mDaiHost), DEFAULT_COLLATERAL_FACTOR);

        uint256 collateralAmount = 1000 ether;
        _getTokens(dai, address(this), collateralAmount);
        dai.approve(address(mDaiHost), collateralAmount);
        mDaiHost.mint(collateralAmount, address(this), 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_BorrowCashNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(1 ether);
    }

    function test_unit_borrow_revertsWith_Operator_MarketBorrowCapReached_whenBorrowCapIsReached(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _whenBorrowCapIsReached(address(mWeth), amount);

        // it should revert with Operator_MarketBorrowCapReached

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_InsufficientLiquidity_whenBorrowTooMuch(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _borrowPrerequisites(address(mWeth), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_InsufficientLiquidity_givenMarketIsNotEntered(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // supply tokens; assure collateral factor is met
        _borrowPrerequisites(address(mWeth), amount * 2);

        // before state
        uint256 balanceUnderlyingBefore = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenBefore = weth.balanceOf(address(mWeth));
        uint256 supplyUnderlyingBefore = weth.totalSupply();
        uint256 totalBorrowsBefore = mWeth.totalBorrows();

        // borrow; should fail

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(amount);

        // borrow; try again
        operator.setCollateralFactor(address(mWeth), DEFAULT_COLLATERAL_FACTOR);
        mWeth.borrow(amount);

        _afterBorrowChecks(
            amount, balanceUnderlyingBefore, balanceUnderlyingMTokenBefore, supplyUnderlyingBefore, totalBorrowsBefore
        );
    }

    ////////////////////////////////////////////////////////////
    //                      TotalBorrows                      //
    ////////////////////////////////////////////////////////////

    function test_unit_totalBorrows_success(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // supply tokens; assure collateral factor is met
        _borrowPrerequisites(address(mWeth), amount * 2);

        // before state
        uint256 balanceUnderlyingBefore = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenBefore = weth.balanceOf(address(mWeth));
        uint256 supplyUnderlyingBefore = weth.totalSupply();
        uint256 totalBorrowsBefore = mWeth.totalBorrows();

        _borrowAndCheck(
            amount, balanceUnderlyingBefore, balanceUnderlyingMTokenBefore, supplyUnderlyingBefore, totalBorrowsBefore
        );
    }

    LiquidationHelper internal helper;

    address internal borrower;

    ////////////////////////////////////////////////////////////
    //                  GetBorrowerPosition                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getBorrowerPosition_success_skipsPausedMarket(address account) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(account != address(0));
        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(
                IOperator.isPaused.selector, address(mWeth), ImTokenOperationTypes.OperationType.Liquidate
            ),
            abi.encode(true)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(account, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(shouldLiquidate, false, "expected shouldLiquidate to equal false");
        assertEq(repayAmount, 0, "expected repayAmount to equal 0");
    }

    function test_fuzz_getBorrowerPosition_success_skipsZeroDebt(address account) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(account != address(0));
        vm.mockCall(
            address(mWeth), abi.encodeWithSelector(ImToken.borrowBalanceStored.selector, account), abi.encode(0)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(account, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(shouldLiquidate, false, "expected shouldLiquidate to equal false");
        assertEq(repayAmount, 0, "expected repayAmount to equal 0");
    }

    function test_fuzz_getBorrowerPosition_success_skipsNoShortfall(address account, uint256 borrowBalance) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(account != address(0));
        borrowBalance = bound(borrowBalance, 1, 1e30);

        vm.mockCall(
            address(mWeth),
            abi.encodeWithSelector(ImToken.borrowBalanceStored.selector, account),
            abi.encode(borrowBalance)
        );
        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(IOperator.getHypotheticalAccountLiquidity.selector, account, address(0), 0, 0),
            abi.encode(0, 0)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(account, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(shouldLiquidate, false, "expected shouldLiquidate to equal false");
        assertEq(repayAmount, 0, "expected repayAmount to equal 0");
    }

    function test_fuzz_getBorrowerPosition_success_liquidatesCorrectly(
        address account,
        uint256 borrowBalance,
        uint256 closeFactor,
        uint256 shortfall
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(account != address(0));
        borrowBalance = bound(borrowBalance, 1, 1e30);
        closeFactor = bound(closeFactor, 1, 1e18);
        shortfall = bound(shortfall, 1, 1e30);

        vm.mockCall(
            address(mWeth),
            abi.encodeWithSelector(ImToken.borrowBalanceStored.selector, account),
            abi.encode(borrowBalance)
        );
        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(IOperator.getHypotheticalAccountLiquidity.selector, account, address(0), 0, 0),
            abi.encode(0, shortfall)
        );
        vm.mockCall(
            address(operator), abi.encodeWithSelector(IOperator.closeFactorMantissa.selector), abi.encode(closeFactor)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(account, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(shouldLiquidate, true, "expected shouldLiquidate to equal true");
        assertEq(
            repayAmount,
            borrowBalance * closeFactor / 1e18,
            "expected repayAmount to equal borrowBalance * closeFactor / 1e18"
        );
    }

    function test_fuzz_getBorrowerPosition_success_fuzzedRepayAmount(
        uint256 borrowBalance,
        uint256 closeFactor,
        uint256 shortfall
    ) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        borrowBalance = bound(borrowBalance, 1, 1e30);
        closeFactor = bound(closeFactor, 1, 1e18);
        shortfall = bound(shortfall, 1, 1e30);

        vm.mockCall(
            address(mWeth),
            abi.encodeWithSelector(ImToken.borrowBalanceStored.selector, borrower),
            abi.encode(borrowBalance)
        );
        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(IOperator.getHypotheticalAccountLiquidity.selector, borrower, address(0), 0, 0),
            abi.encode(0, shortfall)
        );
        vm.mockCall(
            address(operator), abi.encodeWithSelector(IOperator.closeFactorMantissa.selector), abi.encode(closeFactor)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(borrower, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(shouldLiquidate, true, "expected shouldLiquidate to equal true");
        assertEq(
            repayAmount,
            borrowBalance * closeFactor / 1e18,
            "expected repayAmount to equal borrowBalance * closeFactor / 1e18"
        );
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Mint)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.mint(amount, address(this), amount);
    }

    function test_unit_mint_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Mint)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.mint(amount, address(this), amount - 1000);
    }

    function test_unit_mint_revertsWith_Operator_MarketSupplyReached_revertGiven(uint256 amount)
        external
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);
        _whenSupplyCapIsReached(address(mWeth), amount);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        // it should revert with Operator_MarketSupplyReached

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketSupplyReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.mint(amount, address(this), amount - 1000);
    }

    ////////////////////////////////////////////////////////////
    //                    CheckMembership                     //
    ////////////////////////////////////////////////////////////

    function test_unit_checkMembership_success(uint256 amount) external whenMarketIsListed(address(mWeth)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWeth.totalSupply();
        uint256 balanceOfBefore = mWeth.balanceOf(address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bool enteredBefore = operator.checkMembership(address(this), address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(enteredBefore, "expected condition to be false: enteredBefore");

        mWeth.mint(amount, address(this), amount - 1000);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWeth.totalSupply();
        uint256 balanceOfAfter = mWeth.balanceOf(address(this));
        bool enteredAfter = operator.checkMembership(address(this), address(mWeth));
        assertTrue(enteredAfter, "expected condition to be true: enteredAfter");

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");

        // it should transfer underlying from user
        assertGt(balanceWethBefore, balanceWethAfter, "expected balanceWethBefore to be greater than balanceWethAfter");

        assertEq(
            totalSupplyAfter - amount,
            totalSupplyBefore,
            "expected totalSupplyAfter - amount to equal totalSupplyBefore"
        );
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_mint_GivenAmountIs0() external whenMarketIsListed(address(mWeth)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = ZERO_VALUE;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11)); // arithmetic underflow or overflow

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.mint(amount, address(this), amount);
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success() external whenMarketIsListed(address(mWeth)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply wrapAndSupply = new WrapAndSupply(address(weth));
        vm.label(address(wrapAndSupply), "WrapAndSupply Helper");

        uint256 totalSupplyBefore = mWeth.totalSupply();
        uint256 balanceOfBefore = mWeth.balanceOf(address(this));

        wrapAndSupply.wrapAndSupplyOnHostMarket{value: SMALL}(address(mWeth), address(this), SMALL - 1000);

        uint256 totalSupplyAfter = mWeth.totalSupply();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWeth.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");
        assertEq(
            totalSupplyAfter - SMALL, totalSupplyBefore, "expected totalSupplyAfter - SMALL to equal totalSupplyBefore"
        );
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_Operator_UserNotWhitelisted_whenSupplyCapIsGreater(uint256 amount)
        external
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWeth.totalSupply();
        uint256 balanceOfBefore = mWeth.balanceOf(address(this));
        bool enteredBefore = operator.checkMembership(address(this), address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(enteredBefore, "expected condition to be false: enteredBefore");

        operator.setWhitelistStatus(true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        mWeth.mint(amount, address(this), amount - 1000);

        operator.setWhitelistedUser(address(this), false);
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.mint(amount, address(this), amount - 1000);

        operator.setWhitelistedUser(address(this), true);
        mWeth.mint(amount, address(this), amount - 1000);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWeth.totalSupply();
        uint256 balanceOfAfter = mWeth.balanceOf(address(this));
        bool enteredAfter = operator.checkMembership(address(this), address(mWeth));
        assertTrue(enteredAfter, "expected condition to be true: enteredAfter");

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");

        // it should transfer underlying from user
        assertGt(balanceWethBefore, balanceWethAfter, "expected balanceWethBefore to be greater than balanceWethAfter");

        assertEq(
            totalSupplyAfter - amount,
            totalSupplyBefore,
            "expected totalSupplyAfter - amount to equal totalSupplyBefore"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    RedeemUnderlying                    //
    ////////////////////////////////////////////////////////////

    function test_unit_redeemUnderlying_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith_Operator_MarketNotListed_givenMarketIsNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(mWeth), amount / 2);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);
        mWeth.redeem(amount);

        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith_mt_RedeemEmpty_givenRedeemAmountsAre0()
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_RedeemEmpty.selector);
        mWeth.redeem(0);
        vm.expectRevert(mTokenStorage.mt_RedeemEmpty.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeemUnderlying(0);
    }

    function test_unit_redeemUnderlying_revertsWith_mt_RedeemCashNotAvailable_whenTheMarketDoesNotHaveEnoughAssetsForTheRedeemOperation(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mt_RedeemCashNotAvailable

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);
        mWeth.redeem(amount);

        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeemUnderlying(amount);
    }

    ////////////////////////////////////////////////////////////
    //                         Redeem                         //
    ////////////////////////////////////////////////////////////

    function test_unit_redeem_success_redeemTokens(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _redeem(amount, false);
    }

    function test_unit_redeem_success_redeemUnderlying(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _redeem(amount, true);
    }

    ////////////////////////////////////////////////////////////
    //                      RepayBehalf                       //
    ////////////////////////////////////////////////////////////

    function test_unit_repayBehalf_revertsWith_Operator_Paused(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repayBehalf(address(this), amount);
    }

    function test_unit_repayBehalf_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repayBehalf(address(this), amount);
    }

    ////////////////////////////////////////////////////////////
    //                      TotalBorrows                      //
    ////////////////////////////////////////////////////////////

    function test_unit_totalBorrows_success_repayBehalf_GivenAmountIs0(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _repayPrerequisites(address(mWeth), amount * 2, amount);

        uint256 totalBorrowsBefore = mWeth.totalBorrows();
        uint256 accountBorrowBefore = mWeth.borrowBalanceStored(address(this));

        _getTokens(weth, users.alice, amount);
        _resetContext(users.alice);
        weth.approve(address(mWeth), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.RepayBorrow(users.alice, address(this), 0, accountBorrowBefore, totalBorrowsBefore);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repayBehalf(address(this), 0);
        _resetContext(address(this));

        uint256 totalBorrowsAfter = mWeth.totalBorrows();

        // state should be the same

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(totalBorrowsAfter, totalBorrowsBefore, "expected totalBorrowsAfter to equal totalBorrowsBefore");
    }

    struct mErc20_repayBehalf_RepayStateInternal {
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

    ////////////////////////////////////////////////////////////
    //                        Overflow                        //
    ////////////////////////////////////////////////////////////

    function test_unit_overflow_revertsWith_repayBehalf_WhenRepayTooMuch(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        {
            _repayPrerequisites(address(mWeth), amount * 2, amount);
            _getTokens(weth, address(this), amount * 10);
            weth.approve(address(mWeth), amount * 10);
        }

        _getTokens(weth, users.alice, amount);

        mErc20_repayBehalf_RepayStateInternal memory vars;
        // before state
        vars.balanceUnderlyingBefore = weth.balanceOf(users.alice);
        vars.balanceMTokenBefore = mWeth.balanceOf(address(this));
        vars.totalBorrowsBefore = mWeth.totalBorrows();
        vars.accountBorrowBefore = mWeth.borrowBalanceStored(address(this));

        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11)); // panic: arithmetic underflow or overflow

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repayBehalf(address(this), amount * 10);

        _resetContext(users.alice);
        weth.approve(address(mWeth), amount);
        mWeth.repayBehalf(address(this), type(uint256).max);
        _resetContext(address(this));

        // after state

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        vars.balanceUnderlyingAfter = weth.balanceOf(users.alice);
        vars.balanceMTokenAfter = mWeth.balanceOf(address(this));
        vars.totalBorrowsAfter = mWeth.totalBorrows();
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        {
            // it should use only the amount borrowed
            assertEq(
                vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter,
                amount,
                "expected vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter to equal amount"
            );

            // it should have same mToken balance
            assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter, "it should have same mToken balance");

            // it should decrease totalBorrows
            assertGt(
                vars.totalBorrowsBefore,
                vars.totalBorrowsAfter,
                "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
            );

            // it should decrease accountBorrows
            assertGt(
                vars.accountBorrowBefore,
                vars.accountBorrowAfter,
                "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
            );
        }
    }

    ////////////////////////////////////////////////////////////
    //                  BorrowBalanceStored                   //
    ////////////////////////////////////////////////////////////

    function test_unit_borrowBalanceStored_success_repayBehalf_WhenRepayLess(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        mErc20_repayBehalf_RepayStateInternal memory vars;

        _repayPrerequisites(address(mWeth), amount * 2, amount);

        uint256 repayAmount = amount / 10;

        _getTokens(weth, users.alice, repayAmount);

        // before state
        vars.balanceUnderlyingBefore = weth.balanceOf(users.alice);
        vars.balanceMTokenBefore = mWeth.balanceOf(address(this));
        vars.totalMSupplyBefore = mWeth.totalSupply();
        vars.totalBorrowsBefore = mWeth.totalBorrows();
        vars.accountBorrowBefore = mWeth.borrowBalanceStored(address(this));

        _resetContext(users.alice);
        weth.approve(address(mWeth), repayAmount);
        mWeth.repayBehalf(address(this), repayAmount);
        _resetContext(address(this));

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(users.alice);
        vars.balanceMTokenAfter = mWeth.balanceOf(address(this));
        vars.totalMSupplyAfter = mWeth.totalSupply();
        vars.totalBorrowsAfter = mWeth.totalBorrows();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        // it should use only the amount borrowed

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter,
            repayAmount,
            "expected vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter to equal repayAmount"
        );

        // it should have same mToken balance
        assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter, "it should have same mToken balance");

        // it should decrease totalBorrows
        assertGt(
            vars.totalBorrowsBefore,
            vars.totalBorrowsAfter,
            "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
        );
        assertGt(vars.totalBorrowsAfter, 0, "expected vars.totalBorrowsAfter to be greater than 0");

        // it should decrease accountBorrows
        assertGt(
            vars.accountBorrowBefore,
            vars.accountBorrowAfter,
            "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
        );
        assertGt(vars.accountBorrowAfter, 0, "expected vars.accountBorrowAfter to be greater than 0");
    }

    ////////////////////////////////////////////////////////////
    //                         Repay                          //
    ////////////////////////////////////////////////////////////

    function test_unit_repay_revertsWith_Operator_Paused(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenMarketIsListed(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repay(amount);
    }

    function test_unit_repay_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repay(amount);
    }

    ////////////////////////////////////////////////////////////
    //                      TotalBorrows                      //
    ////////////////////////////////////////////////////////////

    function test_unit_totalBorrows_success_repay_GivenAmountIs0(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _repayPrerequisites(address(mWeth), amount * 2, amount);

        uint256 totalBorrowsBefore = mWeth.totalBorrows();
        uint256 accountBorrowBefore = mWeth.borrowBalanceStored(address(this));

        weth.approve(address(mWeth), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.RepayBorrow(address(this), address(this), 0, accountBorrowBefore, totalBorrowsBefore);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repay(0);

        uint256 totalBorrowsAfter = mWeth.totalBorrows();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(totalBorrowsAfter, totalBorrowsBefore, "expected totalBorrowsAfter to equal totalBorrowsBefore");
    }

    struct mErc20_repay_RepayStateInternal {
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

    ////////////////////////////////////////////////////////////
    //                         Repay                          //
    ////////////////////////////////////////////////////////////

    function test_unit_repay_revertsWith_repay_WhenRepayTooMuch(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        {
            _repayPrerequisites(address(mWeth), amount * 2, amount);
            _getTokens(weth, address(this), amount * 10);
            weth.approve(address(mWeth), amount * 10);
        }

        mErc20_repay_RepayStateInternal memory vars;
        vars.balanceUnderlyingBefore = weth.balanceOf(address(this));
        vars.balanceMTokenBefore = mWeth.balanceOf(address(this));
        vars.totalBorrowsBefore = mWeth.totalBorrows();
        vars.accountBorrowBefore = mWeth.borrowBalanceStored(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.repay(amount * 10);

        mWeth.repay(type(uint256).max);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        vars.balanceUnderlyingAfter = weth.balanceOf(address(this));
        vars.balanceMTokenAfter = mWeth.balanceOf(address(this));
        vars.totalBorrowsAfter = mWeth.totalBorrows();
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        assertEq(
            vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter,
            amount,
            "expected vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter to equal amount"
        );
        assertEq(
            vars.balanceMTokenBefore,
            vars.balanceMTokenAfter,
            "expected vars.balanceMTokenBefore to equal vars.balanceMTokenAfter"
        );
        assertGt(
            vars.totalBorrowsBefore,
            vars.totalBorrowsAfter,
            "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
        );
        assertGt(
            vars.accountBorrowBefore,
            vars.accountBorrowAfter,
            "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  BorrowBalanceStored                   //
    ////////////////////////////////////////////////////////////

    function test_unit_borrowBalanceStored_success_repay_WhenRepayLess(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        mErc20_repay_RepayStateInternal memory vars;

        _repayPrerequisites(address(mWeth), amount * 2, amount);

        uint256 repayAmount = amount / 10;
        weth.approve(address(mWeth), repayAmount);

        vars.balanceUnderlyingBefore = weth.balanceOf(address(this));
        vars.balanceMTokenBefore = mWeth.balanceOf(address(this));
        vars.totalBorrowsBefore = mWeth.totalBorrows();
        vars.accountBorrowBefore = mWeth.borrowBalanceStored(address(this));

        mWeth.repay(repayAmount);

        vars.balanceUnderlyingAfter = weth.balanceOf(address(this));
        vars.balanceMTokenAfter = mWeth.balanceOf(address(this));
        vars.totalBorrowsAfter = mWeth.totalBorrows();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter,
            repayAmount,
            "expected vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter to equal repayAmount"
        );
        assertEq(
            vars.balanceMTokenBefore,
            vars.balanceMTokenAfter,
            "expected vars.balanceMTokenBefore to equal vars.balanceMTokenAfter"
        );
        assertGt(
            vars.totalBorrowsBefore,
            vars.totalBorrowsAfter,
            "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
        );
        assertGt(vars.totalBorrowsAfter, 0, "expected vars.totalBorrowsAfter to be greater than 0");
        assertGt(
            vars.accountBorrowBefore,
            vars.accountBorrowAfter,
            "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
        );
        assertGt(vars.accountBorrowAfter, 0, "expected vars.accountBorrowAfter to be greater than 0");
    }

    ////////////////////////////////////////////////////////////
    //                         IERC20                         //
    ////////////////////////////////////////////////////////////

    function test_unit_iERC20_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 100;
        _getTokens(dai, address(mWeth), amount);

        uint256 adminBalanceBefore = dai.balanceOf(address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.sweepToken(IERC20(address(dai)), amount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(dai.balanceOf(address(mWeth)), 0, "expected dai.balanceOf(address(mWeth)) to equal 0");
        assertEq(
            dai.balanceOf(address(this)),
            adminBalanceBefore + amount,
            "expected dai.balanceOf(address(this)) to equal adminBalanceBefore + amount"
        );
    }

    function test_fuzz_iERC20_success(uint256 amount) external {
        amount = bound(amount, 1, LARGE);
        _getTokens(dai, address(mWeth), amount);

        uint256 adminBalanceBefore = dai.balanceOf(address(this));

        mWeth.sweepToken(IERC20(address(dai)), amount);

        assertEq(dai.balanceOf(address(mWeth)), 0, "expected dai.balanceOf(address(mWeth)) to equal 0");
        assertEq(
            dai.balanceOf(address(this)),
            adminBalanceBefore + amount,
            "expected dai.balanceOf(address(this)) to equal adminBalanceBefore + amount"
        );
    }

    ////////////////////////////////////////////////////////////
    //                       SweepToken                       //
    ////////////////////////////////////////////////////////////

    function test_unit_sweepToken_revertsWith_mErc20_TokenNotValid_revertsOnUnderlying() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mErc20.mErc20_TokenNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.sweepToken(IERC20(address(weth)), 1);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    // stack too deep
    function _borrowAndCheck(
        uint256 amount,
        uint256 balanceUnderlyingBefore,
        uint256 balanceUnderlyingMTokenBefore,
        uint256 supplyUnderlyingBefore,
        uint256 totalBorrowsBefore
    ) private {
        uint256 accountBorrowsBefore = mWeth.borrowBalanceStored(address(this));

        // borrow

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Borrow(address(this), amount, accountBorrowsBefore + amount, totalBorrowsBefore + amount);
        mWeth.borrow(amount);

        _afterBorrowChecks(
            amount, balanceUnderlyingBefore, balanceUnderlyingMTokenBefore, supplyUnderlyingBefore, totalBorrowsBefore
        );
    }

    function _afterBorrowChecks(
        uint256 amount,
        uint256 balanceUnderlyingBefore,
        uint256 balanceUnderlyingMTokenBefore,
        uint256 supplyUnderlyingBefore,
        uint256 totalBorrowsBefore
    ) private view {
        // after state
        bool memberAfter = operator.checkMembership(address(this), address(mWeth));
        uint256 balanceUnderlyingAfter = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenAfter = weth.balanceOf(address(mWeth));
        uint256 supplyUnderlyingAfter = weth.totalSupply();
        uint256 totalBorrowsAfter = mWeth.totalBorrows();

        // it shoud activate ther market for sender
        assertTrue(memberAfter, "expected condition to be true: memberAfter");

        // it should transfer underlying token to sender
        assertGt(
            balanceUnderlyingAfter,
            balanceUnderlyingBefore,
            "expected balanceUnderlyingAfter to be greater than balanceUnderlyingBefore"
        );
        assertEq(balanceUnderlyingAfter - amount, balanceUnderlyingBefore, "aderlyingBefore)");

        // it should not modify underlying supply
        assertEq(supplyUnderlyingBefore, supplyUnderlyingAfter, "it should not modify underlying supply");

        // it should decrease balance of underlying from mToken
        assertGt(
            balanceUnderlyingMTokenBefore,
            balanceUnderlyingMTokenAfter,
            "expected balanceUnderlyingMTokenBefore to be greater than balanceUnderlyingMTokenAfter"
        );

        // it should increase totalBorrows
        assertGt(
            totalBorrowsAfter, totalBorrowsBefore, "expected totalBorrowsAfter to be greater than totalBorrowsBefore"
        );
    }

    function _redeem(uint256 amount, bool underlying) private {
        _borrowPrerequisites(address(mWeth), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 supplyMTokenBefore = mWeth.totalSupply();
        uint256 balanceMTokenBefore = mWeth.balanceOf(address(this));

        amount = amount - DEFAULT_INFLATION_INCREASE;
        uint256 exchangeRate = mWeth.exchangeRateStored();
        uint256 redeemTokens = underlying ? (amount * EXP_SCALE) / exchangeRate : amount;
        uint256 redeemAmount = underlying ? amount : (exchangeRate * amount) / EXP_SCALE;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Transfer(address(this), address(mWeth), redeemTokens);
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Redeem(address(this), redeemAmount, redeemTokens);

        if (underlying) mWeth.redeemUnderlying(amount);
        else mWeth.redeem(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 supplyMTokenAfter = mWeth.totalSupply();
        uint256 balanceMTokenAfter = mWeth.balanceOf(address(this));

        // it should transfer underlying to redeemer
        assertEq(balanceWethBefore + amount, balanceWethAfter, "it should transfer underlying to redeemer");

        // it should decrease totalSupply of mToken
        assertGt(
            supplyMTokenBefore, supplyMTokenAfter, "expected supplyMTokenBefore to be greater than supplyMTokenAfter"
        );
        assertEq(
            supplyMTokenBefore - amount,
            supplyMTokenAfter,
            "expected supplyMTokenBefore - amount to equal supplyMTokenAfter"
        );

        // it should decrease redeemer balance of mToken
        assertGt(
            balanceMTokenBefore,
            balanceMTokenAfter,
            "expected balanceMTokenBefore to be greater than balanceMTokenAfter"
        );
        assertEq(
            balanceMTokenBefore - amount,
            balanceMTokenAfter,
            "expected balanceMTokenBefore - amount to equal balanceMTokenAfter"
        );
    }
}
