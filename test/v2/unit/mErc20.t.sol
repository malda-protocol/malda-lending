// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {mErc20Upgradable} from "src/mToken/mErc20Upgradable.sol";
import {mErc20Immutable} from "src/mToken/mErc20Immutable.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";
import {IOperator} from "src/interfaces/IOperator.sol";
import {ImTokenOperationTypes, ImToken} from "src/interfaces/ImToken.sol";
import {LiquidationHelper} from "src/utils/LiquidationHelper.sol";
import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {mErc20} from "src/mToken/mErc20.sol";

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
    function setUp() public override {
        super.setUp();

        helper = new LiquidationHelper();
        vm.label(address(helper), "LiquidationHelper");
        borrower = users.alice;
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_mErc20Immutable_AdminNotValid() external {
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
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mErc20Upgradable.mErc20Upgradable_AdminNotValid.selector);
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

    function test_unit_initializeHarness_revertsWith_mt_AddressNotValid_variant3() external {
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
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

    function test_unit_initializeHarness_revertsWith_mt_AddressNotValid_variant2() external {
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        harness.initializeHarness(
            address(weth), address(0), address(interestModel), 1e18, "Market WETH", "mWeth", 18, payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_AddressNotValid() external {
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        harness.initializeHarness(
            address(weth), address(operator), address(0), 1e18, "Market WETH", "mWeth", 18, payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_NameNotValid() external {
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mTokenStorage.mt_NameNotValid.selector);
        harness.initializeHarness(
            address(weth), address(operator), address(interestModel), 1e18, "", "mWeth", 18, payable(address(this))
        );
    }

    function test_unit_initializeHarness_revertsWith_mt_SymbolNotValid() external {
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mTokenStorage.mt_SymbolNotValid.selector);
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
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mTokenStorage.mt_DecimalsNotValid.selector);
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
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();

        vm.expectRevert(mTokenStorage.mt_ExchangeRateNotValid.selector);
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
        mErc20UpgradableHarnessV2 harness = new mErc20UpgradableHarnessV2();
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

        vm.expectRevert(mTokenStorage.mt_AlreadyInitialized.selector);
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
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_MarketNotListed_variant4(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_EmptyPrice_revertGiven(uint256 amount)
        external
        whenPriceIs(ZERO_VALUE)
        whenUnderlyingPriceIs(ZERO_VALUE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        mWeth.borrow(amount);
    }

    modifier mErc20_borrow_givenAmountIsGreaterThan0() {
        // does nothing; only for readability purposes
        _;
    }

    function test_unit_borrow_revertsWith(uint256 amount)
        external
        mErc20_borrow_givenAmountIsGreaterThan0
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mt_BorrowCashNotAvailable but it actually reverts with InsufficientLiquidity for non cross-chain tokens
        // cannot test this in a non-external flow
        vm.expectRevert();
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_mt_BorrowCashNotAvailable()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));
        operator.supportMarket(address(mDaiHost));
        operator.setCollateralFactor(address(mDaiHost), DEFAULT_COLLATERAL_FACTOR);

        uint256 collateralAmount = 1000 ether;
        _getTokens(dai, address(this), collateralAmount);
        dai.approve(address(mDaiHost), collateralAmount);
        mDaiHost.mint(collateralAmount, address(this), 0);

        vm.expectRevert(mTokenStorage.mt_BorrowCashNotAvailable.selector);
        mWeth.borrow(1 ether);
    }

    function test_unit_borrow_revertsWith_Operator_MarketBorrowCapReached_whenBorrowCapIsReached(uint256 amount)
        external
        mErc20_borrow_givenAmountIsGreaterThan0
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        amount = bound(amount, SMALL, LARGE);

        _whenBorrowCapIsReached(address(mWeth), amount);

        // it should revert with Operator_MarketBorrowCapReached
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);
        mWeth.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_InsufficientLiquidity_whenBorrowTooMuch(uint256 amount)
        external
        mErc20_borrow_givenAmountIsGreaterThan0
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        _borrowPrerequisites(address(mWeth), amount);

        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        mWeth.borrow(amount);
    }

    modifier mErc20_borrow_whenStateIsValid() {
        // does nothing; only for readability purposes
        _;
    }

    function test_unit_borrow_revertsWith_Operator_InsufficientLiquidity_givenMarketIsNotEntered(uint256 amount)
        external
        mErc20_borrow_givenAmountIsGreaterThan0
        mErc20_borrow_whenStateIsValid
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
    {
        amount = bound(amount, SMALL, LARGE);

        // supply tokens; assure collateral factor is met
        _borrowPrerequisites(address(mWeth), amount * 2);

        // before state
        uint256 balanceUnderlyingBefore = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenBefore = weth.balanceOf(address(mWeth));
        uint256 supplyUnderlyingBefore = weth.totalSupply();
        uint256 totalBorrowsBefore = mWeth.totalBorrows();

        // borrow; should fail
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
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
        mErc20_borrow_givenAmountIsGreaterThan0
        mErc20_borrow_whenStateIsValid
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
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

    // stack too deep
    function _borrowAndCheck(
        uint256 amount,
        uint256 balanceUnderlyingBefore,
        uint256 balanceUnderlyingMTokenBefore,
        uint256 supplyUnderlyingBefore,
        uint256 totalBorrowsBefore
    ) private {
        // borrow
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
        assertTrue(memberAfter);

        // it should transfer underlying token to sender
        assertGt(balanceUnderlyingAfter, balanceUnderlyingBefore);
        assertEq(balanceUnderlyingAfter - amount, balanceUnderlyingBefore);

        // it should not modify underlying supply
        assertEq(supplyUnderlyingBefore, supplyUnderlyingAfter);

        // it should decrease balance of underlying from mToken
        assertGt(balanceUnderlyingMTokenBefore, balanceUnderlyingMTokenAfter);

        // it should increase totalBorrows
        assertGt(totalBorrowsAfter, totalBorrowsBefore);
    }

    LiquidationHelper internal helper;

    address internal borrower;

    ////////////////////////////////////////////////////////////
    //                  GetBorrowerPosition                   //
    ////////////////////////////////////////////////////////////

    function test_unit_getBorrowerPosition_success_skipsPausedMarket() public {
        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(
                IOperator.isPaused.selector, address(mWeth), ImTokenOperationTypes.OperationType.Liquidate
            ),
            abi.encode(true)
        );

        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(borrower, address(mWeth));
        assertEq(shouldLiquidate, false);
        assertEq(repayAmount, 0);
    }

    function test_unit_getBorrowerPosition_success_skipsZeroDebt() public {
        vm.mockCall(
            address(mWeth), abi.encodeWithSelector(ImToken.borrowBalanceStored.selector, borrower), abi.encode(0)
        );

        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(borrower, address(mWeth));
        assertEq(shouldLiquidate, false);
        assertEq(repayAmount, 0);
    }

    function test_unit_getBorrowerPosition_success_skipsNoShortfall() public {
        uint256 borrowBalance = 1 ether;

        vm.mockCall(
            address(mWeth),
            abi.encodeWithSelector(ImToken.borrowBalanceStored.selector, borrower),
            abi.encode(borrowBalance)
        );
        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(IOperator.getHypotheticalAccountLiquidity.selector, borrower, address(0), 0, 0),
            abi.encode(0, 0)
        );

        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(borrower, address(mWeth));
        assertEq(shouldLiquidate, false);
        assertEq(repayAmount, 0);
    }

    function test_unit_getBorrowerPosition_success_liquidatesCorrectly() public {
        uint256 borrowBalance = 1 ether;
        uint256 closeFactor = 50 * 1e16; // 50%
        uint256 shortfall = 1 ether;

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

        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(borrower, address(mWeth));
        assertEq(shouldLiquidate, true);
        assertEq(repayAmount, borrowBalance * closeFactor / 1 ether);
    }

    function test_fuzz_getBorrowerPosition_success_fuzzedRepayAmount(
        uint256 borrowBalance,
        uint256 closeFactor,
        uint256 shortfall
    ) public {
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

        (bool shouldLiquidate, uint256 repayAmount) = helper.getBorrowerPosition(borrower, address(mWeth));
        assertEq(shouldLiquidate, true);
        assertEq(repayAmount, borrowBalance * closeFactor / 1e18);
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Mint)
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.mint(amount, address(this), amount);
    }

    function test_unit_mint_revertsWith_Operator_MarketNotListed_variant3(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Mint)
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.mint(amount, address(this), amount - 1000);
    }

    function test_unit_mint_revertsWith_Operator_MarketSupplyReached_revertGiven(uint256 amount)
        external
        whenMarketIsListed(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);
        _whenSupplyCapIsReached(address(mWeth), amount);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        // it should revert with Operator_MarketSupplyReached
        vm.expectRevert(OperatorStorage.Operator_MarketSupplyReached.selector);
        mWeth.mint(amount, address(this), amount - 1000);
    }

    ////////////////////////////////////////////////////////////
    //                    CheckMembership                     //
    ////////////////////////////////////////////////////////////

    function test_unit_checkMembership_success(uint256 amount) external whenMarketIsListed(address(mWeth)) {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWeth.totalSupply();
        uint256 balanceOfBefore = mWeth.balanceOf(address(this));
        bool enteredBefore = operator.checkMembership(address(this), address(mWeth));
        assertFalse(enteredBefore);

        mWeth.mint(amount, address(this), amount - 1000);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWeth.totalSupply();
        uint256 balanceOfAfter = mWeth.balanceOf(address(this));
        bool enteredAfter = operator.checkMembership(address(this), address(mWeth));
        assertTrue(enteredAfter);

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore);

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore);

        // it should transfer underlying from user
        assertGt(balanceWethBefore, balanceWethAfter);

        assertEq(totalSupplyAfter - amount, totalSupplyBefore);
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_mint_GivenAmountIs0() external whenMarketIsListed(address(mWeth)) {
        uint256 amount = ZERO_VALUE;
        vm.expectRevert(); //arithmetic underflow or overflow
        mWeth.mint(amount, address(this), amount);
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success() external whenMarketIsListed(address(mWeth)) {
        WrapAndSupply wrapAndSupply = new WrapAndSupply(address(weth));
        vm.label(address(wrapAndSupply), "WrapAndSupply Helper");

        uint256 totalSupplyBefore = mWeth.totalSupply();
        uint256 balanceOfBefore = mWeth.balanceOf(address(this));

        wrapAndSupply.wrapAndSupplyOnHostMarket{value: SMALL}(address(mWeth), address(this), SMALL - 1000);

        uint256 totalSupplyAfter = mWeth.totalSupply();
        uint256 balanceOfAfter = mWeth.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore);

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore);
        assertEq(totalSupplyAfter - SMALL, totalSupplyBefore);
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_Operator_UserNotWhitelisted_whenSupplyCapIsGreater(uint256 amount)
        external
        whenMarketIsListed(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWeth.totalSupply();
        uint256 balanceOfBefore = mWeth.balanceOf(address(this));
        bool enteredBefore = operator.checkMembership(address(this), address(mWeth));
        assertFalse(enteredBefore);

        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        mWeth.mint(amount, address(this), amount - 1000);

        operator.setWhitelistedUser(address(this), false);
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        mWeth.mint(amount, address(this), amount - 1000);

        operator.setWhitelistedUser(address(this), true);
        mWeth.mint(amount, address(this), amount - 1000);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWeth.totalSupply();
        uint256 balanceOfAfter = mWeth.balanceOf(address(this));
        bool enteredAfter = operator.checkMembership(address(this), address(mWeth));
        assertTrue(enteredAfter);

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore);

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore);

        // it should transfer underlying from user
        assertGt(balanceWethBefore, balanceWethAfter);

        assertEq(totalSupplyAfter - amount, totalSupplyBefore);
    }

    ////////////////////////////////////////////////////////////
    //                    RedeemUnderlying                    //
    ////////////////////////////////////////////////////////////

    function test_unit_redeemUnderlying_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith_Operator_MarketNotListed_givenMarketIsNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWeth.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(mWeth), amount);
        vm.expectRevert();
        mWeth.redeem(amount);

        vm.expectRevert();
        mWeth.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith_mt_RedeemEmpty_givenRedeemAmountsAre0()
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        vm.expectRevert(mTokenStorage.mt_RedeemEmpty.selector);
        mWeth.redeem(0);
        vm.expectRevert(mTokenStorage.mt_RedeemEmpty.selector);
        mWeth.redeemUnderlying(0);
    }

    modifier mErc20_redeem_givenAmountIsGreaterThan0() {
        // does nothing; only for readability purposes
        _;
    }

    function test_unit_redeemUnderlying_revertsWith_mt_RedeemCashNotAvailable_whenTheMarketDoesNotHaveEnoughAssetsForTheRedeemOperation(uint256 amount)
        external
        mErc20_redeem_givenAmountIsGreaterThan0
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mt_RedeemCashNotAvailable
        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);
        mWeth.redeem(amount);

        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);
        mWeth.redeemUnderlying(amount);
    }

    ////////////////////////////////////////////////////////////
    //                         Redeem                         //
    ////////////////////////////////////////////////////////////

    function test_unit_redeem_success(uint256 amount)
        external
        mErc20_redeem_givenAmountIsGreaterThan0
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        amount = bound(amount, SMALL, LARGE);

        _redeem(amount, false);
    }

    function test_unit_redeem_success_variant2(uint256 amount)
        external
        mErc20_redeem_givenAmountIsGreaterThan0
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWeth))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        amount = bound(amount, SMALL, LARGE);

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

    ////////////////////////////////////////////////////////////
    //                      RepayBehalf                       //
    ////////////////////////////////////////////////////////////

    function test_unit_repayBehalf_revertsWith_Operator_Paused_variant2(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenMarketIsListed(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.repayBehalf(address(this), amount);
    }

    function test_unit_repayBehalf_revertsWith_Operator_MarketNotListed_variant2(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
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
        amount = bound(amount, SMALL, LARGE);

        _repayPrerequisites(address(mWeth), amount * 2, amount);

        uint256 totalBorrowsBefore = mWeth.totalBorrows();

        _getTokens(weth, users.alice, amount);
        _resetContext(users.alice);
        weth.approve(address(mWeth), amount);
        mWeth.repayBehalf(address(this), 0);
        _resetContext(address(this));

        uint256 totalBorrowsAfter = mWeth.totalBorrows();

        // state should be the same
        assertEq(totalBorrowsAfter, totalBorrowsBefore);
    }

    modifier mErc20_repayBehalf_givenAmountIsGreaterThan0() {
        // does nothing; only for readability purposes
        _;
    }

    modifier mErc20_repayBehalf_whenStateIsValid() {
        // does nothing; only for readability purposes
        _;
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
        mErc20_repayBehalf_givenAmountIsGreaterThan0
        mErc20_repayBehalf_whenStateIsValid
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
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

        vm.expectRevert(); //panic: arithmetic underflow or overflow (0x11)
        mWeth.repayBehalf(address(this), amount * 10);

        _resetContext(users.alice);
        weth.approve(address(mWeth), amount);
        mWeth.repayBehalf(address(this), type(uint256).max);
        _resetContext(address(this));

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(users.alice);
        vars.balanceMTokenAfter = mWeth.balanceOf(address(this));
        vars.totalBorrowsAfter = mWeth.totalBorrows();
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        {
            // it should use only the amount borrowed
            assertEq(vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter, amount);

            // it should have same mToken balance
            assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter);

            // it should decrease totalBorrows
            assertGt(vars.totalBorrowsBefore, vars.totalBorrowsAfter);

            // it should decrease accountBorrows
            assertGt(vars.accountBorrowBefore, vars.accountBorrowAfter);
        }
    }

    ////////////////////////////////////////////////////////////
    //                  BorrowBalanceStored                   //
    ////////////////////////////////////////////////////////////

    function test_unit_borrowBalanceStored_success_repayBehalf_WhenRepayLess(uint256 amount)
        external
        mErc20_repayBehalf_givenAmountIsGreaterThan0
        mErc20_repayBehalf_whenStateIsValid
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
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
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        // it should use only the amount borrowed
        assertEq(vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter, repayAmount);

        // it should have same mToken balance
        assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter);

        // it should decrease totalBorrows
        assertGt(vars.totalBorrowsBefore, vars.totalBorrowsAfter);
        assertGt(vars.totalBorrowsAfter, 0);

        // it should decrease accountBorrows
        assertGt(vars.accountBorrowBefore, vars.accountBorrowAfter);
        assertGt(vars.accountBorrowAfter, 0);
    }

    ////////////////////////////////////////////////////////////
    //                         Repay                          //
    ////////////////////////////////////////////////////////////

    function test_unit_repay_revertsWith_Operator_Paused(uint256 amount)
        external
        whenPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenMarketIsListed(address(mWeth))
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWeth.repay(amount);
    }

    function test_unit_repay_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
    {
        amount = bound(amount, SMALL, LARGE);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
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
        amount = bound(amount, SMALL, LARGE);

        _repayPrerequisites(address(mWeth), amount * 2, amount);

        uint256 totalBorrowsBefore = mWeth.totalBorrows();

        weth.approve(address(mWeth), amount);
        mWeth.repay(0);

        uint256 totalBorrowsAfter = mWeth.totalBorrows();

        assertEq(totalBorrowsAfter, totalBorrowsBefore);
    }

    modifier mErc20_repay_givenAmountIsGreaterThan0() {
        _;
    }

    modifier mErc20_repay_whenStateIsValid() {
        _;
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
        mErc20_repay_givenAmountIsGreaterThan0
        mErc20_repay_whenStateIsValid
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
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

        vm.expectRevert();
        mWeth.repay(amount * 10);

        mWeth.repay(type(uint256).max);

        vars.balanceUnderlyingAfter = weth.balanceOf(address(this));
        vars.balanceMTokenAfter = mWeth.balanceOf(address(this));
        vars.totalBorrowsAfter = mWeth.totalBorrows();
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        assertEq(vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter, amount);
        assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter);
        assertGt(vars.totalBorrowsBefore, vars.totalBorrowsAfter);
        assertGt(vars.accountBorrowBefore, vars.accountBorrowAfter);
    }

    ////////////////////////////////////////////////////////////
    //                  BorrowBalanceStored                   //
    ////////////////////////////////////////////////////////////

    function test_unit_borrowBalanceStored_success_repay_WhenRepayLess(uint256 amount)
        external
        mErc20_repay_givenAmountIsGreaterThan0
        mErc20_repay_whenStateIsValid
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenMarketEntered(address(mWeth))
    {
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
        vars.accountBorrowAfter = mWeth.borrowBalanceStored(address(this));

        assertEq(vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter, repayAmount);
        assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter);
        assertGt(vars.totalBorrowsBefore, vars.totalBorrowsAfter);
        assertGt(vars.totalBorrowsAfter, 0);
        assertGt(vars.accountBorrowBefore, vars.accountBorrowAfter);
        assertGt(vars.accountBorrowAfter, 0);
    }

    ////////////////////////////////////////////////////////////
    //                         IERC20                         //
    ////////////////////////////////////////////////////////////

    function test_unit_iERC20_success() external {
        uint256 amount = 100;
        _getTokens(dai, address(mWeth), amount);

        uint256 adminBalanceBefore = dai.balanceOf(address(this));
        mWeth.sweepToken(IERC20(address(dai)), amount);

        assertEq(dai.balanceOf(address(mWeth)), 0);
        assertEq(dai.balanceOf(address(this)), adminBalanceBefore + amount);
    }

    ////////////////////////////////////////////////////////////
    //                       SweepToken                       //
    ////////////////////////////////////////////////////////////

    function test_unit_sweepToken_revertsWith_mErc20_TokenNotValid_revertsOnUnderlying() external {
        vm.expectRevert(mErc20.mErc20_TokenNotValid.selector);
        mWeth.sweepToken(IERC20(address(weth)), 1);
    }
}
