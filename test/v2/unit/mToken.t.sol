// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {Roles} from "src/Roles.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";
import {IOperatorDefender} from "src/interfaces/IOperator.sol";

contract GoodInterestRateModel {
    function isInterestRateModel() external pure returns (bool) {
        return true;
    }
}

contract BadInterestRateModel {
    function isInterestRateModel() external pure returns (bool) {
        return false;
    }
}

contract mTokenTest is BaseMTokenTest {
    function setUp() public override {
        super.setUp();
        borrower = users.alice;
        liquidator = users.bob;
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_NonAdminSetOperator() external {
        vm.prank(users.alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.setOperator(address(operator));
    }

    ////////////////////////////////////////////////////////////
    //                       SetOperator                        //
    ////////////////////////////////////////////////////////////

    function test_unitSetOperator_success_Updates() external {
        address newOperator = users.bob;
        mWeth.setOperator(newOperator);

        assertEq(mWeth.operator(), newOperator);
    }

    function test_unitSetOperator_revertsWith_RevertWhenZero() external {
        vm.expectRevert(mTokenStorage.mt_OperatorNotValid.selector);
        mWeth.setOperator(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     SetRolesOperator                     //
    ////////////////////////////////////////////////////////////

    function test_unitSetRolesOperator_success_Updates() external {
        Roles newRoles = new Roles(address(this));
        mWeth.setRolesOperator(address(newRoles));

        assertEq(address(mWeth.rolesOperator()), address(newRoles));
    }

    function test_unitSetRolesOperator_revertsWith_RevertWhenZero() external {
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        mWeth.setRolesOperator(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_NonAdminSetInterestRateModel() external {
        GoodInterestRateModel newModel = new GoodInterestRateModel();

        vm.prank(users.alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.setInterestRateModel(address(newModel));
    }

    ////////////////////////////////////////////////////////////
    //                   SetInterestRateModel                   //
    ////////////////////////////////////////////////////////////

    function test_unitSetInterestRateModel_success_Updates() external {
        GoodInterestRateModel newModel = new GoodInterestRateModel();
        mWeth.setInterestRateModel(address(newModel));

        assertEq(mWeth.interestRateModel(), address(newModel));
    }

    function test_unitSetInterestRateModel_revertsWith_RevertWhenInvalid() external {
        BadInterestRateModel badModel = new BadInterestRateModel();

        vm.expectRevert(mTokenStorage.mt_MarketMethodNotValid.selector);
        mWeth.setInterestRateModel(address(badModel));
    }

    ////////////////////////////////////////////////////////////
    //                 SetBorrowRateMaxMantissa                 //
    ////////////////////////////////////////////////////////////

    function test_unitSetBorrowRateMaxMantissa_success_NoSupply(uint256 newMax) external {
        newMax = bound(newMax, 0, 1e18);
        mWeth.setBorrowRateMaxMantissa(newMax);

        assertEq(mWeth.borrowRateMaxMantissa(), newMax);
    }

    function test_unitSetBorrowRateMaxMantissa_success_WithSupply(uint256 mintAmount, uint256 newMax) external {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        newMax = bound(newMax, 0, 1e18);

        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        mWeth.setBorrowRateMaxMantissa(newMax);

        assertEq(mWeth.borrowRateMaxMantissa(), newMax);
    }

    ////////////////////////////////////////////////////////////
    //                     SetReserveFactor                     //
    ////////////////////////////////////////////////////////////

    function test_unitSetReserveFactor_revertsWith_RevertWhenTooHigh() external {
        vm.expectRevert(mTokenStorage.mt_ReserveFactorTooHigh.selector);
        mWeth.setReserveFactor(1e18 + 1);
    }

    ////////////////////////////////////////////////////////////
    //            AccrueInterestChecksBorrowRateMax             //
    ////////////////////////////////////////////////////////////

    function test_unitAccrueInterestChecksBorrowRateMax_success() external {
        mWeth.setBorrowRateMaxMantissa(1e18);

        vm.warp(block.timestamp + 1);
        mWeth.accrueInterest();

        assertEq(mWeth.borrowRateMaxMantissa(), 1e18);
    }

    ////////////////////////////////////////////////////////////
    //                     SetPendingAdmin                      //
    ////////////////////////////////////////////////////////////

    function test_unitSetPendingAdmin_revertsWith_RevertWhenZero() external {
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        mWeth.setPendingAdmin(payable(address(0)));
    }

    function test_unitSetPendingAdmin_revertsWith_RevertWhenNotAdmin() external {
        vm.prank(users.alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.setPendingAdmin(payable(users.bob));
    }

    function test_unitSetPendingAdmin_success_AndAcceptAdmin() external {
        address newAdmin = users.bob;

        mWeth.setPendingAdmin(payable(newAdmin));
        assertEq(mWeth.pendingAdmin(), newAdmin);

        vm.prank(newAdmin);
        mWeth.acceptAdmin();

        assertEq(mWeth.admin(), newAdmin);
        assertEq(mWeth.pendingAdmin(), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                       AcceptAdmin                        //
    ////////////////////////////////////////////////////////////

    function test_unitAcceptAdmin_revertsWith_RevertWhenNotPending() external {
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);
        mWeth.acceptAdmin();
    }

    ////////////////////////////////////////////////////////////
    //                   ApproveAndAllowance                    //
    ////////////////////////////////////////////////////////////

    function test_fuzzApproveAndAllowance_success(uint256 amount) external {
        amount = bound(amount, 0, LARGE);

        mWeth.approve(users.bob, amount);

        assertEq(mWeth.allowance(address(this), users.bob), amount);
    }

    ////////////////////////////////////////////////////////////
    //                         Transfer                         //
    ////////////////////////////////////////////////////////////

    function test_unitTransfer_revertsWith_RevertWhenSameAddress(uint256 mintAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        vm.expectRevert(mTokenStorage.mt_TransferNotValid.selector);
        mWeth.transfer(address(this), 1);
    }

    function test_fuzzTransfer_success_UpdatesBalances(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(address(this));
        transferAmount = bound(transferAmount, 1, senderBalanceBefore);

        mWeth.transfer(users.bob, transferAmount);

        assertEq(mWeth.balanceOf(address(this)), senderBalanceBefore - transferAmount);
        assertEq(mWeth.balanceOf(users.bob), transferAmount);
    }

    ////////////////////////////////////////////////////////////
    //                       TransferFrom                       //
    ////////////////////////////////////////////////////////////

    function test_fuzzTransferFrom_success_UsesAllowance(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        _getTokens(weth, users.alice, mintAmount);
        vm.startPrank(users.alice);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, users.alice, 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(users.alice);
        transferAmount = bound(transferAmount, 1, senderBalanceBefore);
        mWeth.approve(users.bob, transferAmount);
        vm.stopPrank();

        vm.prank(users.bob);
        mWeth.transferFrom(users.alice, users.carol, transferAmount);

        assertEq(mWeth.allowance(users.alice, users.bob), 0);
        assertEq(mWeth.balanceOf(users.alice), senderBalanceBefore - transferAmount);
        assertEq(mWeth.balanceOf(users.carol), transferAmount);
    }

    function test_fuzzTransferFrom_success_ByOwner_SkipsAllowance(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        _getTokens(weth, users.alice, mintAmount);
        vm.startPrank(users.alice);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, users.alice, 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(users.alice);
        transferAmount = bound(transferAmount, 1, senderBalanceBefore);

        mWeth.transferFrom(users.alice, users.bob, transferAmount);
        vm.stopPrank();

        assertEq(mWeth.allowance(users.alice, users.alice), 0);
        assertEq(mWeth.balanceOf(users.alice), senderBalanceBefore - transferAmount);
        assertEq(mWeth.balanceOf(users.bob), transferAmount);
    }

    ////////////////////////////////////////////////////////////
    //        TotalBorrowsCurrentAndBorrowBalanceCurrent        //
    ////////////////////////////////////////////////////////////

    function test_fuzzTotalBorrowsCurrentAndBorrowBalanceCurrent_success(uint256 borrowAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
        borrowAmount = bound(borrowAmount, SMALL, LARGE / 2);
        _borrowPrerequisites(address(mWeth), borrowAmount * 2);

        mWeth.borrow(borrowAmount);

        uint256 totalBorrowsCurrent = mWeth.totalBorrowsCurrent();
        uint256 borrowBalanceCurrent = mWeth.borrowBalanceCurrent(address(this));

        assertEq(totalBorrowsCurrent, mWeth.totalBorrows());
        assertEq(borrowBalanceCurrent, mWeth.borrowBalanceStored(address(this)));
    }

    ////////////////////////////////////////////////////////////
    //                    BorrowWithReceiver                    //
    ////////////////////////////////////////////////////////////

    function test_fuzzBorrowWithReceiver_success_FromMigrator(uint256 supplyAmount, uint256 borrowAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWethHost))
    {
        supplyAmount = bound(supplyAmount, MEDIUM, LARGE);
        borrowAmount = bound(borrowAmount, SMALL, supplyAmount / 2);

        _getTokens(weth, address(this), supplyAmount);
        weth.approve(address(mWethHost), supplyAmount);
        mWethHost.mint(supplyAmount, address(this), 0);

        mWethHost.setMigrator(address(this));

        uint256 receiverBalanceBefore = weth.balanceOf(users.bob);
        mWethHost.mintOrBorrowMigration(false, borrowAmount, users.bob, address(this), 0);

        assertEq(weth.balanceOf(users.bob), receiverBalanceBefore + borrowAmount);
        assertEq(mWethHost.borrowBalanceStored(address(this)), borrowAmount);
    }

    ////////////////////////////////////////////////////////////
    //        BalanceOfUnderlyingAndExchangeRateCurrent         //
    ////////////////////////////////////////////////////////////

    function test_unitBalanceOfUnderlyingAndExchangeRateCurrent_success(uint256 mintAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        uint256 exchangeRate = mWeth.exchangeRateCurrent();
        uint256 tokenBalance = mWeth.balanceOf(address(this));
        uint256 balanceUnderlying = mWeth.balanceOfUnderlying(address(this));

        assertEq(balanceUnderlying, (tokenBalance * exchangeRate) / 1e18);
    }

    ////////////////////////////////////////////////////////////
    //                     GetCashAndRates                      //
    ////////////////////////////////////////////////////////////

    function test_fuzzGetCashAndRates_success(uint256 mintAmount) external {
        mintAmount = bound(mintAmount, SMALL, LARGE);
        operator.supportMarket(address(mWeth));

        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        uint256 cash = mWeth.getCash();
        assertEq(cash, mWeth.totalUnderlying());

        uint256 borrows = mWeth.totalBorrows();
        uint256 reserves = mWeth.totalReserves();

        uint256 expectedBorrowRate =
            IInterestRateModel(mWeth.interestRateModel()).getBorrowRate(cash, borrows, reserves);
        uint256 expectedSupplyRate = IInterestRateModel(mWeth.interestRateModel())
            .getSupplyRate(cash, borrows, reserves, mWeth.reserveFactorMantissa());

        assertEq(mWeth.borrowRatePerBlock(), expectedBorrowRate);
        assertEq(mWeth.supplyRatePerBlock(), expectedSupplyRate);
    }

    ////////////////////////////////////////////////////////////
    //                   AddAndReduceReserves                   //
    ////////////////////////////////////////////////////////////

    function test_fuzzAddAndReduceReserves_success_AsAdmin(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);
        mWeth.addReserves(amount);

        uint256 totalReservesBefore = mWeth.totalReserves();
        uint256 totalUnderlyingBefore = mWeth.totalUnderlying();
        uint256 reduceAmount = amount / 2;

        mWeth.reduceReserves(reduceAmount);

        assertEq(mWeth.totalReserves(), totalReservesBefore - reduceAmount);
        assertEq(mWeth.totalUnderlying(), totalUnderlyingBefore - reduceAmount);
    }

    function test_fuzzAddAndReduceReserves_success_AsGuardian(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethHost), amount);
        mWethHost.addReserves(amount);

        address guardian = users.guardian;
        roles.allowFor(guardian, roles.GUARDIAN_RESERVE(), true);

        uint256 reduceAmount = amount / 2;

        vm.prank(guardian);
        mWethHost.reduceReserves(reduceAmount);

        assertEq(mWethHost.totalReserves(), amount - reduceAmount);
    }

    ////////////////////////////////////////////////////////////
    //                      ReduceReserves                      //
    ////////////////////////////////////////////////////////////

    function test_fuzzReduceReserves_revertsWith_RevertWhenNotAllowed(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);
        mWeth.addReserves(amount);
        mWeth.setRolesOperator(address(roles));

        vm.prank(users.alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdminOrRole.selector);
        mWeth.reduceReserves(amount / 2);
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_MinAmountOutTooHigh() external whenMarketIsListed(address(mWeth)) {
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        vm.expectRevert(mTokenStorage.mt_MinAmountNotValid.selector);
        mWeth.mint(amount, address(this), amount);
    }

    ////////////////////////////////////////////////////////////
    //                           Mint                           //
    ////////////////////////////////////////////////////////////

    function test_unitMint_success_WhenTotalSupplyNonZero() external whenMarketIsListed(address(mWeth)) {
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount * 2);
        weth.approve(address(mWeth), amount * 2);

        mWeth.mint(amount, address(this), 0);
        uint256 totalSupplyBefore = mWeth.totalSupply();

        mWeth.mint(amount, address(this), 0);
        assertEq(mWeth.totalSupply(), totalSupplyBefore + amount);
    }

    ////////////////////////////////////////////////////////////
    //                      ReduceReserves                      //
    ////////////////////////////////////////////////////////////

    function test_unitReduceReserves_revertsWith_RevertWhen_CashNotAvailable()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));
        operator.setCollateralFactor(address(mWeth), DEFAULT_COLLATERAL_FACTOR);

        uint256 supplyAmount = 200 ether;
        uint256 reservesAmount = 10 ether;
        _getTokens(weth, address(this), supplyAmount + reservesAmount);
        weth.approve(address(mWeth), supplyAmount);
        mWeth.mint(supplyAmount, address(this), 0);

        weth.approve(address(mWeth), reservesAmount);
        mWeth.addReserves(reservesAmount);

        mWeth.borrow(150 ether);

        vm.expectRevert(mTokenStorage.mt_ReserveCashNotAvailable.selector);
        mWeth.reduceReserves(70 ether);
    }

    function test_unitReduceReserves_revertsWith_RevertWhen_AmountExceedsReserves() external {
        operator.supportMarket(address(mWeth));

        uint256 supplyAmount = 100 ether;
        _getTokens(weth, address(this), supplyAmount + 10 ether);
        weth.approve(address(mWeth), supplyAmount + 10 ether);
        mWeth.mint(supplyAmount, address(this), 0);

        mWeth.addReserves(10 ether);

        vm.expectRevert(mTokenStorage.mt_ReserveCashNotAvailable.selector);
        mWeth.reduceReserves(20 ether);
    }

    address internal borrower;
    address internal liquidator;

    ////////////////////////////////////////////////////////////
    //                          Seize                           //
    ////////////////////////////////////////////////////////////

    function test_unitSeize_revertsWith_RevertWhen_BorrowerIsLiquidator() external {
        operator.supportMarket(address(mWeth));
        operator.supportMarket(address(mDaiHost));

        vm.prank(address(mDaiHost));
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mWeth.seize(borrower, borrower, 1);
    }

    ////////////////////////////////////////////////////////////
    //                        Liquidate                         //
    ////////////////////////////////////////////////////////////

    function test_unitLiquidate_revertsWith_RevertWhen_BorrowerIsLiquidator() external {
        vm.prank(liquidator);
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mDaiHost.liquidate(liquidator, 1 ether, address(mWeth));
    }

    function test_unitLiquidate_revertsWith_RevertWhen_RepayAmountIsZero() external {
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mDaiHost.liquidate(borrower, 0, address(mWeth));
    }

    function test_unitLiquidate_revertsWith_RevertWhen_RepayAmountIsMax() external {
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mDaiHost.liquidate(borrower, type(uint256).max, address(mWeth));
    }

    function test_unitLiquidate_revertsWith_RevertWhen_CollateralBlockTimestampNotValid() external {
        uint256 repayAmount = 1 ether;

        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(
                IOperatorDefender.beforeMTokenLiquidate.selector,
                address(mDaiHost),
                address(mWeth),
                borrower,
                repayAmount
            ),
            abi.encode()
        );
        vm.mockCall(
            address(mWeth),
            abi.encodeWithSelector(mWeth.accrualBlockTimestamp.selector),
            abi.encode(block.timestamp + 1)
        );

        vm.expectRevert(mTokenStorage.mt_CollateralBlockTimestampNotValid.selector);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    function test_unitLiquidate_revertsWith_RevertWhen_PriceFetchFailed() external {
        uint256 borrowAmount = 100 ether;
        uint256 repayAmount = 10 ether;
        _setupBorrowerPosition(borrower, 1000 ether, borrowAmount);

        _fundLiquidator(repayAmount);

        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(
                IOperatorDefender.beforeMTokenLiquidate.selector,
                address(mDaiHost),
                address(mWeth),
                borrower,
                repayAmount
            ),
            abi.encode()
        );

        oracleOperator.setUnderlyingPrice(0);

        vm.prank(liquidator);
        vm.expectRevert(mTokenStorage.mt_PriceFetchFailed.selector);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    function test_unitLiquidate_revertsWith_RevertWhen_SeizeTooMuch() external {
        uint256 borrowAmount = 100 ether;
        uint256 repayAmount = 10 ether;
        _setupBorrowerPosition(borrower, 1000 ether, borrowAmount);

        operator.setLiquidationIncentive(address(mWeth), 1e18);
        _fundLiquidator(repayAmount);

        vm.mockCall(
            address(operator),
            abi.encodeWithSelector(
                IOperatorDefender.beforeMTokenLiquidate.selector,
                address(mDaiHost),
                address(mWeth),
                borrower,
                repayAmount
            ),
            abi.encode()
        );
        vm.mockCall(address(mWeth), abi.encodeWithSelector(mWeth.balanceOf.selector, borrower), abi.encode(uint256(0)));

        vm.prank(liquidator);
        vm.expectRevert(mTokenStorage.mt_LiquidateSeizeTooMuch.selector);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    function _setupBorrowerPosition(address account, uint256 collateralAmount, uint256 borrowAmount) internal {
        operator.supportMarket(address(mWeth));
        operator.supportMarket(address(mDaiHost));
        oracleOperator.setUnderlyingPrice(DEFAULT_ORACLE_PRICE);
        operator.setCollateralFactor(address(mWeth), DEFAULT_COLLATERAL_FACTOR);
        operator.setCollateralFactor(address(mDaiHost), DEFAULT_COLLATERAL_FACTOR);

        _getTokens(weth, account, collateralAmount);
        vm.startPrank(account);
        weth.approve(address(mWeth), collateralAmount);
        mWeth.mint(collateralAmount, account, 0);
        vm.stopPrank();

        uint256 cashAmount = borrowAmount * 2;
        _getTokens(dai, address(this), cashAmount);
        dai.approve(address(mDaiHost), cashAmount);
        mDaiHost.mint(cashAmount, address(this), 0);

        vm.prank(account);
        mDaiHost.borrow(borrowAmount);
    }

    function _fundLiquidator(uint256 repayAmount) internal {
        _getTokens(dai, liquidator, repayAmount);
        vm.startPrank(liquidator);
        dai.approve(address(mDaiHost), repayAmount);
        vm.stopPrank();
    }
}
