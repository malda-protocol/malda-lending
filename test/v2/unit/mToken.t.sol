// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IOperatorDefender} from "src/interfaces/IOperator.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {Roles} from "src/Roles.sol";

import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";

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
    uint256 internal constant EXP_SCALE = 1e18;
    uint256 internal constant MIN_FUZZ_AMOUNT = 1;
    uint256 internal constant MIN_FUZZ_MINT_AMOUNT = DEFAULT_INFLATION_INCREASE + 1;
    uint256 internal constant MIN_FUZZ_AMOUNT_WITH_SETUP = DEFAULT_INFLATION_INCREASE * 2;
    uint256 internal constant MAX_FUZZ_AMOUNT = type(uint128).max;

    function setUp() public override {
        super.setUp();
        borrower = users.alice;
        liquidator = users.bob;
    }

    ////////////////////////////////////////////////////////////
    //                      SetOperator                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setOperator_revertsWith_mt_OnlyAdmin() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWeth.setOperator(address(operator));
    }

    function test_unit_setOperator_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address newOperator = users.bob;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewOperator(mWeth.operator(), newOperator);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setOperator(newOperator);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(mWeth.operator(), newOperator, "expected mWeth.operator() to equal newOperator");
    }

    function test_unit_setOperator_revertsWith_mt_OperatorNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OperatorNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setOperator(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                    SetRolesOperator                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setRolesOperator_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Roles newRoles = new Roles(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewRolesOperator(address(mWeth.rolesOperator()), address(newRoles));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setRolesOperator(address(newRoles));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(mWeth.rolesOperator()),
            address(newRoles),
            "expected address(mWeth.rolesOperator()) to equal address(newRoles)"
        );
    }

    function test_unit_setRolesOperator_revertsWith_mt_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setRolesOperator(address(0));
    }

    function test_unit_setRolesOperator_revertsWith_mt_OnlyAdmin() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWeth.setRolesOperator(address(roles));
    }

    ////////////////////////////////////////////////////////////
    //                  SetInterestRateModel                  //
    ////////////////////////////////////////////////////////////

    function test_unit_setInterestRateModel_revertsWith_mt_OnlyAdmin() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        GoodInterestRateModel newModel = new GoodInterestRateModel();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWeth.setInterestRateModel(address(newModel));
    }

    function test_unit_setInterestRateModel_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        GoodInterestRateModel newModel = new GoodInterestRateModel();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewMarketInterestRateModel(mWeth.interestRateModel(), address(newModel));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setInterestRateModel(address(newModel));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWeth.interestRateModel(),
            address(newModel),
            "expected mWeth.interestRateModel() to equal address(newModel)"
        );
    }

    function test_unit_setInterestRateModel_revertsWith_mt_MarketMethodNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        BadInterestRateModel badModel = new BadInterestRateModel();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_MarketMethodNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setInterestRateModel(address(badModel));
    }

    ////////////////////////////////////////////////////////////
    //                SetBorrowRateMaxMantissa                //
    ////////////////////////////////////////////////////////////

    function test_unit_setBorrowRateMaxMantissa_success_noSupply(uint256 newMax) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newMax = bound(newMax, 0, 1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewBorrowRateMaxMantissa(mWeth.borrowRateMaxMantissa(), newMax);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setBorrowRateMaxMantissa(newMax);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(mWeth.borrowRateMaxMantissa(), newMax, "expected mWeth.borrowRateMaxMantissa() to equal newMax");
    }

    function test_unit_setBorrowRateMaxMantissa_success_withSupply(uint256 mintAmount, uint256 newMax) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, MIN_FUZZ_MINT_AMOUNT, MAX_FUZZ_AMOUNT);
        newMax = bound(newMax, 0, 1e18);

        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewBorrowRateMaxMantissa(mWeth.borrowRateMaxMantissa(), newMax);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setBorrowRateMaxMantissa(newMax);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(mWeth.borrowRateMaxMantissa(), newMax, "expected mWeth.borrowRateMaxMantissa() to equal newMax");
    }

    ////////////////////////////////////////////////////////////
    //                    SetReserveFactor                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setReserveFactor_revertsWith_mt_ReserveFactorTooHigh() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_ReserveFactorTooHigh.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setReserveFactor(1e18 + 1);
    }

    function test_unit_setReserveFactor_revertsWith_mt_OnlyAdmin(uint256 newReserveFactorMantissa) external {
        newReserveFactorMantissa = bound(newReserveFactorMantissa, 0, 1e18);

        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);

        vm.prank(users.alice);
        mWeth.setReserveFactor(newReserveFactorMantissa);
    }

    function test_fuzz_setReserveFactor_success(uint256 newReserveFactorMantissa) external {
        newReserveFactorMantissa = bound(newReserveFactorMantissa, 0, 1e18);

        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewReserveFactor(mWeth.reserveFactorMantissa(), newReserveFactorMantissa);

        mWeth.setReserveFactor(newReserveFactorMantissa);

        assertEq(
            mWeth.reserveFactorMantissa(),
            newReserveFactorMantissa,
            "expected mWeth.reserveFactorMantissa() to equal newReserveFactorMantissa"
        );
    }

    ////////////////////////////////////////////////////////////
    //                     AccrueInterest                     //
    ////////////////////////////////////////////////////////////

    function test_unit_accrueInterest_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mWeth.setBorrowRateMaxMantissa(1e18);

        vm.warp(block.timestamp + 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        _expectAccrueInterest();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.accrueInterest();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(mWeth.borrowRateMaxMantissa(), 1e18, "expected mWeth.borrowRateMaxMantissa() to equal 1e18");
    }

    function test_unit_accrueInterest_revertsWith_mt_BorrowRateTooHigh() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mWeth.setBorrowRateMaxMantissa(1);
        vm.warp(block.timestamp + 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_BorrowRateTooHigh.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.accrueInterest();
    }

    ////////////////////////////////////////////////////////////
    //                    SetPendingAdmin                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setPendingAdmin_revertsWith_mt_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.setPendingAdmin(payable(address(0)));
    }

    function test_unit_setPendingAdmin_revertsWith_mt_OnlyAdmin() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWeth.setPendingAdmin(payable(users.bob));
    }

    ////////////////////////////////////////////////////////////
    //                        Payable                         //
    ////////////////////////////////////////////////////////////

    function test_unit_setPendingAdmin_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address newAdmin = users.bob;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewPendingAdmin(newAdmin);
        mWeth.setPendingAdmin(payable(newAdmin));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(mWeth.pendingAdmin(), newAdmin, "expected mWeth.pendingAdmin() to equal newAdmin");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.AdminAccepted(newAdmin);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(newAdmin);
        mWeth.acceptAdmin();

        assertEq(mWeth.admin(), newAdmin, "expected mWeth.admin() to equal newAdmin");
        assertEq(mWeth.pendingAdmin(), address(0), "expected mWeth.pendingAdmin() to equal address(0)");
    }

    ////////////////////////////////////////////////////////////
    //                      AcceptAdmin                       //
    ////////////////////////////////////////////////////////////

    function test_unit_acceptAdmin_revertsWith_mt_OnlyAdmin() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.acceptAdmin();
    }

    ////////////////////////////////////////////////////////////
    //                        Approve                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_approve_success(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 0, MAX_FUZZ_AMOUNT);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Approval(address(this), users.bob, amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.approve(users.bob, amount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWeth.allowance(address(this), users.bob),
            amount,
            "expected mWeth.allowance(address(this), users.bob) to equal amount"
        );
    }

    ////////////////////////////////////////////////////////////
    //                        Transfer                        //
    ////////////////////////////////////////////////////////////

    function test_unit_transfer_revertsWith_mt_TransferNotValid(uint256 mintAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, MIN_FUZZ_MINT_AMOUNT, MAX_FUZZ_AMOUNT);
        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_TransferNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.transfer(address(this), 1);
    }

    function test_fuzz_transfer_success(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, MIN_FUZZ_MINT_AMOUNT, MAX_FUZZ_AMOUNT);
        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(address(this));
        transferAmount = bound(transferAmount, 0, senderBalanceBefore);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Transfer(address(this), users.bob, transferAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.transfer(users.bob, transferAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWeth.balanceOf(address(this)),
            senderBalanceBefore - transferAmount,
            "expected mWeth.balanceOf(address(this)) to equal senderBalanceBefore - transferAmount"
        );
        assertEq(
            mWeth.balanceOf(users.bob), transferAmount, "expected mWeth.balanceOf(users.bob) to equal transferAmount"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      TransferFrom                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_transferFrom_success_usesAllowance(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, MIN_FUZZ_MINT_AMOUNT, MAX_FUZZ_AMOUNT);
        _getTokens(weth, users.alice, mintAmount);
        vm.startPrank(users.alice);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, users.alice, 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(users.alice);
        transferAmount = bound(transferAmount, 0, senderBalanceBefore);
        mWeth.approve(users.bob, transferAmount);
        vm.stopPrank();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Transfer(users.alice, users.carol, transferAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.transferFrom(users.alice, users.carol, transferAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWeth.allowance(users.alice, users.bob), 0, "expected mWeth.allowance(users.alice, users.bob) to equal 0"
        );
        assertEq(
            mWeth.balanceOf(users.alice),
            senderBalanceBefore - transferAmount,
            "expected mWeth.balanceOf(users.alice) to equal senderBalanceBefore - transferAmount"
        );
        assertEq(
            mWeth.balanceOf(users.carol),
            transferAmount,
            "expected mWeth.balanceOf(users.carol) to equal transferAmount"
        );
    }

    function test_fuzz_transferFrom_success_byOwner_SkipsAllowance(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, MIN_FUZZ_MINT_AMOUNT, MAX_FUZZ_AMOUNT);
        _getTokens(weth, users.alice, mintAmount);
        vm.startPrank(users.alice);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, users.alice, 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(users.alice);
        transferAmount = bound(transferAmount, 0, senderBalanceBefore);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Transfer(users.alice, users.bob, transferAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.transferFrom(users.alice, users.bob, transferAmount);
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWeth.allowance(users.alice, users.alice),
            0,
            "expected mWeth.allowance(users.alice, users.alice) to equal 0"
        );
        assertEq(
            mWeth.balanceOf(users.alice),
            senderBalanceBefore - transferAmount,
            "expected mWeth.balanceOf(users.alice) to equal senderBalanceBefore - transferAmount"
        );
        assertEq(
            mWeth.balanceOf(users.bob), transferAmount, "expected mWeth.balanceOf(users.bob) to equal transferAmount"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  BorrowBalanceCurrent                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_borrowBalanceCurrent_success(uint256 borrowAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWeth))
        whenNotPaused(address(mWeth), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWeth))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        borrowAmount = bound(borrowAmount, MIN_FUZZ_AMOUNT_WITH_SETUP, MAX_FUZZ_AMOUNT / 2);
        _borrowPrerequisites(address(mWeth), borrowAmount * 2);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Borrow(address(this), borrowAmount, borrowAmount, borrowAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.borrow(borrowAmount);

        uint256 totalBorrowsCurrent = mWeth.totalBorrowsCurrent();
        uint256 borrowBalanceCurrent = mWeth.borrowBalanceCurrent(address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            totalBorrowsCurrent, mWeth.totalBorrows(), "expected totalBorrowsCurrent to equal mWeth.totalBorrows()"
        );
        assertEq(
            borrowBalanceCurrent,
            mWeth.borrowBalanceStored(address(this)),
            "expected borrowBalanceCurrent to equal mWeth.borrowBalanceStored(address(this))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                 MintOrBorrowMigration                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_mintOrBorrowMigration_success(uint256 supplyAmount, uint256 borrowAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        supplyAmount = bound(supplyAmount, MIN_FUZZ_MINT_AMOUNT * 4, MAX_FUZZ_AMOUNT);
        borrowAmount = bound(borrowAmount, MIN_FUZZ_MINT_AMOUNT, supplyAmount / 4);

        _getTokens(weth, address(this), supplyAmount);
        weth.approve(address(mWethHost), supplyAmount);
        mWethHost.mint(supplyAmount, address(this), 0);

        mWethHost.setMigrator(address(this));

        uint256 receiverBalanceBefore = weth.balanceOf(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImErc20Host.mErc20Host_BorrowMigration(address(this), borrowAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintOrBorrowMigration(false, borrowAmount, users.bob, address(this), 0);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            weth.balanceOf(users.bob),
            receiverBalanceBefore + borrowAmount,
            "expected weth.balanceOf(users.bob) to equal receiverBalanceBefore + borrowAmount"
        );
        assertEq(
            mWethHost.borrowBalanceStored(address(this)),
            borrowAmount,
            "expected mWethHost.borrowBalanceStored(address(this)) to equal borrowAmount"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  BalanceOfUnderlying                   //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOfUnderlying_success(uint256 mintAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, MIN_FUZZ_MINT_AMOUNT, MAX_FUZZ_AMOUNT);
        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        uint256 exchangeRate = mWeth.exchangeRateCurrent();
        uint256 tokenBalance = mWeth.balanceOf(address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 balanceUnderlying = mWeth.balanceOfUnderlying(address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            balanceUnderlying,
            (tokenBalance * exchangeRate) / 1e18,
            "expected balanceUnderlying to equal (tokenBalance * exchangeRate) / 1e18"
        );
    }

    ////////////////////////////////////////////////////////////
    //                        GetCash                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getCash_success(uint256 mintAmount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mintAmount = bound(mintAmount, MIN_FUZZ_MINT_AMOUNT, MAX_FUZZ_AMOUNT);
        operator.supportMarket(address(mWeth));

        _getTokens(weth, address(this), mintAmount);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, address(this), 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 cash = mWeth.getCash();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(cash, mWeth.totalUnderlying(), "expected cash to equal mWeth.totalUnderlying()");

        uint256 borrows = mWeth.totalBorrows();
        uint256 reserves = mWeth.totalReserves();

        uint256 expectedBorrowRate =
            IInterestRateModel(mWeth.interestRateModel()).getBorrowRate(cash, borrows, reserves);
        uint256 expectedSupplyRate = IInterestRateModel(mWeth.interestRateModel())
            .getSupplyRate(cash, borrows, reserves, mWeth.reserveFactorMantissa());

        assertEq(
            mWeth.borrowRatePerBlock(),
            expectedBorrowRate,
            "expected mWeth.borrowRatePerBlock() to equal expectedBorrowRate"
        );
        assertEq(
            mWeth.supplyRatePerBlock(),
            expectedSupplyRate,
            "expected mWeth.supplyRatePerBlock() to equal expectedSupplyRate"
        );
    }

    ////////////////////////////////////////////////////////////
    //                     ReduceReserves                     //
    ////////////////////////////////////////////////////////////

    function test_fuzz_reduceReserves_success_asAdmin(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 0, MAX_FUZZ_AMOUNT);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);
        mWeth.addReserves(amount);

        uint256 totalReservesBefore = mWeth.totalReserves();
        uint256 totalUnderlyingBefore = mWeth.totalUnderlying();
        uint256 reduceAmount = amount / 2;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.ReservesReduced(address(this), reduceAmount, totalReservesBefore - reduceAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.reduceReserves(reduceAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWeth.totalReserves(),
            totalReservesBefore - reduceAmount,
            "expected mWeth.totalReserves() to equal totalReservesBefore - reduceAmount"
        );
        assertEq(
            mWeth.totalUnderlying(),
            totalUnderlyingBefore - reduceAmount,
            "expected mWeth.totalUnderlying() to equal totalUnderlyingBefore - reduceAmount"
        );
    }

    function test_fuzz_reduceReserves_success_asGuardian(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 0, MAX_FUZZ_AMOUNT);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethHost), amount);
        mWethHost.addReserves(amount);

        address guardian = users.guardian;
        roles.allowFor(guardian, roles.GUARDIAN_RESERVE(), true);

        uint256 reduceAmount = amount / 2;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.ReservesReduced(guardian, reduceAmount, amount - reduceAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        mWethHost.reduceReserves(reduceAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWethHost.totalReserves(),
            amount - reduceAmount,
            "expected mWethHost.totalReserves() to equal amount - reduceAmount"
        );
    }

    function test_fuzz_reduceReserves_revertsWith_mt_OnlyAdminOrRole(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 0, MAX_FUZZ_AMOUNT);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);
        mWeth.addReserves(amount);
        mWeth.setRolesOperator(address(roles));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OnlyAdminOrRole.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWeth.reduceReserves(amount / 2);
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_mt_MinAmountNotValid() external whenMarketIsListed(address(mWeth)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_MinAmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.mint(amount, address(this), amount);
    }

    function test_unit_mint_success() external whenMarketIsListed(address(mWeth)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount * 2);
        weth.approve(address(mWeth), amount * 2);

        mWeth.mint(amount, address(this), 0);
        uint256 totalSupplyBefore = mWeth.totalSupply();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Mint(address(this), address(this), amount, amount);
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Transfer(address(mWeth), address(this), amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.mint(amount, address(this), 0);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWeth.totalSupply(),
            totalSupplyBefore + amount,
            "expected mWeth.totalSupply() to equal totalSupplyBefore + amount"
        );
    }

    ////////////////////////////////////////////////////////////
    //                         Redeem                         //
    ////////////////////////////////////////////////////////////

    function test_unit_redeemUnderlying_success()
        external
        whenMarketIsListed(address(mWeth))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = SMALL;
        uint256 redeemAmount = amount / 4;
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);
        mWeth.mint(amount, address(this), 0);

        uint256 underlyingBalanceBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWeth.totalSupply();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeemUnderlying(redeemAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            weth.balanceOf(address(this)),
            underlyingBalanceBefore + redeemAmount,
            "expected weth.balanceOf(address(this)) to equal underlyingBalanceBefore + redeemAmount"
        );
        assertLt(
            mWeth.totalSupply(), totalSupplyBefore, "expected mWeth.totalSupply() to be less than totalSupplyBefore"
        );
    }

    function test_unit_redeem_success()
        external
        whenMarketIsListed(address(mWeth))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);
        mWeth.mint(amount, address(this), 0);

        uint256 redeemTokens = mWeth.balanceOf(address(this)) / 2;
        uint256 underlyingBalanceBefore = weth.balanceOf(address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeem(redeemTokens);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(
            weth.balanceOf(address(this)),
            underlyingBalanceBefore,
            "expected weth.balanceOf(address(this)) to be greater than underlyingBalanceBefore"
        );
    }

    // NOTE (as of 2026-02-11): unreachable invariant.
    // Public redeem entrypoints are mutually exclusive by construction:
    // `redeem(x)` maps to `(redeemTokensIn=x, redeemAmountIn=0)` and
    // `redeemUnderlying(y)` maps to `(redeemTokensIn=0, redeemAmountIn=y)`.
    function test_unit_unreachableInvariant_publicRedeemEntryPointsAreMutuallyExclusive()
        external
        whenMarketIsListed(address(mWeth))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount * 2);
        weth.approve(address(mWeth), amount * 2);
        mWeth.mint(amount, address(this), 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.redeem(amount / 4);
        mWeth.mint(amount, address(this), 0);
        mWeth.redeemUnderlying(amount / 4);
    }

    ////////////////////////////////////////////////////////////
    //                     ReduceReserves                     //
    ////////////////////////////////////////////////////////////

    function test_unit_reduceReserves_revertsWith_mt_ReserveCashNotAvailable_whenBorrowDrainsCash()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
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

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_ReserveCashNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.reduceReserves(70 ether);
    }

    function test_unit_reduceReserves_revertsWith_mt_ReserveCashNotAvailable_whenReservesExceedCash() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));

        uint256 supplyAmount = 100 ether;
        _getTokens(weth, address(this), supplyAmount + 10 ether);
        weth.approve(address(mWeth), supplyAmount + 10 ether);
        mWeth.mint(supplyAmount, address(this), 0);

        mWeth.addReserves(10 ether);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_ReserveCashNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWeth.reduceReserves(20 ether);
    }

    address internal borrower;
    address internal liquidator;

    ////////////////////////////////////////////////////////////
    //                         Seize                          //
    ////////////////////////////////////////////////////////////

    function test_unit_seize_revertsWith_mt_InvalidInput() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWeth));
        operator.supportMarket(address(mDaiHost));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(mDaiHost));
        mWeth.seize(borrower, borrower, 1);
    }

    ////////////////////////////////////////////////////////////
    //                       Liquidate                        //
    ////////////////////////////////////////////////////////////

    function test_unit_liquidate_revertsWith_mt_InvalidInput_whenLiquidatorIsBorrower() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        mDaiHost.liquidate(liquidator, 1 ether, address(mWeth));
    }

    function test_unit_liquidate_revertsWith_mt_InvalidInput_whenRepayAmountZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mDaiHost.liquidate(borrower, 0, address(mWeth));
    }

    function test_unit_liquidate_revertsWith_mt_InvalidInput_whenRepayAmountMax() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mDaiHost.liquidate(borrower, type(uint256).max, address(mWeth));
    }

    function test_unit_liquidate_revertsWith_mt_CollateralBlockTimestampNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
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

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_CollateralBlockTimestampNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    function test_unit_liquidate_revertsWith_mt_PriceFetchFailed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
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

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_PriceFetchFailed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    function test_unit_liquidate_revertsWith_mt_LiquidateSeizeTooMuch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
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

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_LiquidateSeizeTooMuch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _expectAccrueInterest() internal {
        uint256 cashPrior = mWeth.getCash();
        uint256 borrowsPrior = mWeth.totalBorrows();
        uint256 reservesPrior = mWeth.totalReserves();
        uint256 borrowIndexPrior = mWeth.borrowIndex();
        uint256 accrualBlockTimestampPrior = mWeth.accrualBlockTimestamp();

        uint256 borrowRateMantissa =
            IInterestRateModel(mWeth.interestRateModel()).getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        uint256 blockDelta = block.timestamp - accrualBlockTimestampPrior;
        uint256 simpleInterestFactor = borrowRateMantissa * blockDelta;
        uint256 interestAccumulated = (simpleInterestFactor * borrowsPrior) / EXP_SCALE;
        uint256 totalBorrowsNew = interestAccumulated + borrowsPrior;
        uint256 borrowIndexNew = borrowIndexPrior + (simpleInterestFactor * borrowIndexPrior) / EXP_SCALE;

        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
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

        // ~~~~~~~~~~ Call ~~~~~~~~~~
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
