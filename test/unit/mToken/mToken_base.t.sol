// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mToken_base is mToken_Unit_Shared {
    function testFuzz_ApproveAndAllowance(uint256 amount) external {
        amount = bound(amount, 0, LARGE);

        mWeth.approve(bob, amount);

        assertEq(mWeth.allowance(address(this), bob), amount);
    }

    function test_Transfer_RevertWhenSameAddress(uint256 mintAmount)
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

    function testFuzz_Transfer_UpdatesBalances(uint256 mintAmount, uint256 transferAmount)
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

        mWeth.transfer(bob, transferAmount);

        assertEq(mWeth.balanceOf(address(this)), senderBalanceBefore - transferAmount);
        assertEq(mWeth.balanceOf(bob), transferAmount);
    }

    function testFuzz_TransferFrom_UsesAllowance(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        _getTokens(weth, alice, mintAmount);
        vm.startPrank(alice);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, alice, 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(alice);
        transferAmount = bound(transferAmount, 1, senderBalanceBefore);
        mWeth.approve(bob, transferAmount);
        vm.stopPrank();

        vm.prank(bob);
        mWeth.transferFrom(alice, foo, transferAmount);

        assertEq(mWeth.allowance(alice, bob), 0);
        assertEq(mWeth.balanceOf(alice), senderBalanceBefore - transferAmount);
        assertEq(mWeth.balanceOf(foo), transferAmount);
    }

    function testFuzz_TransferFrom_ByOwner_SkipsAllowance(uint256 mintAmount, uint256 transferAmount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        operator.supportMarket(address(mWeth));

        mintAmount = bound(mintAmount, SMALL, LARGE);
        _getTokens(weth, alice, mintAmount);
        vm.startPrank(alice);
        weth.approve(address(mWeth), mintAmount);
        mWeth.mint(mintAmount, alice, 0);

        uint256 senderBalanceBefore = mWeth.balanceOf(alice);
        transferAmount = bound(transferAmount, 1, senderBalanceBefore);

        mWeth.transferFrom(alice, bob, transferAmount);
        vm.stopPrank();

        assertEq(mWeth.allowance(alice, alice), 0);
        assertEq(mWeth.balanceOf(alice), senderBalanceBefore - transferAmount);
        assertEq(mWeth.balanceOf(bob), transferAmount);
    }

    function testFuzz_TotalBorrowsCurrentAndBorrowBalanceCurrent(uint256 borrowAmount)
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

    function testFuzz_BorrowWithReceiver_FromMigrator(uint256 supplyAmount, uint256 borrowAmount)
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

        uint256 receiverBalanceBefore = weth.balanceOf(bob);
        mWethHost.mintOrBorrowMigration(false, borrowAmount, bob, address(this), 0);

        assertEq(weth.balanceOf(bob), receiverBalanceBefore + borrowAmount);
        assertEq(mWethHost.borrowBalanceStored(address(this)), borrowAmount);
    }

    function test_BalanceOfUnderlyingAndExchangeRateCurrent(uint256 mintAmount)
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

    function testFuzz_GetCashAndRates(uint256 mintAmount) external {
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

    function testFuzz_AddAndReduceReserves_AsAdmin(uint256 amount) external {
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

    function testFuzz_AddAndReduceReserves_AsGuardian(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethHost), amount);
        mWethHost.addReserves(amount);

        address guardian = address(0xBEEF);
        roles.allowFor(guardian, roles.GUARDIAN_RESERVE(), true);

        uint256 reduceAmount = amount / 2;

        vm.prank(guardian);
        mWethHost.reduceReserves(reduceAmount);

        assertEq(mWethHost.totalReserves(), amount - reduceAmount);
    }

    function testFuzz_ReduceReserves_RevertWhenNotAllowed(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);
        mWeth.addReserves(amount);
        mWeth.setRolesOperator(address(roles));

        vm.prank(alice);
        vm.expectRevert(mTokenStorage.mt_OnlyAdminOrRole.selector);
        mWeth.reduceReserves(amount / 2);
    }

    function test_RevertWhen_MinAmountOutTooHigh() external whenMarketIsListed(address(mWeth)) {
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWeth), amount);

        vm.expectRevert(mTokenStorage.mt_MinAmountNotValid.selector);
        mWeth.mint(amount, address(this), amount);
    }

    function test_Mint_WhenTotalSupplyNonZero() external whenMarketIsListed(address(mWeth)) {
        uint256 amount = SMALL;
        _getTokens(weth, address(this), amount * 2);
        weth.approve(address(mWeth), amount * 2);

        mWeth.mint(amount, address(this), 0);
        uint256 totalSupplyBefore = mWeth.totalSupply();

        mWeth.mint(amount, address(this), 0);
        assertEq(mWeth.totalSupply(), totalSupplyBefore + amount);
    }

    function test_ReduceReserves_RevertWhen_CashNotAvailable() external whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE) {
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

    function test_ReduceReserves_RevertWhen_AmountExceedsReserves() external {
        operator.supportMarket(address(mWeth));

        uint256 supplyAmount = 100 ether;
        _getTokens(weth, address(this), supplyAmount + 10 ether);
        weth.approve(address(mWeth), supplyAmount + 10 ether);
        mWeth.mint(supplyAmount, address(this), 0);

        mWeth.addReserves(10 ether);

        vm.expectRevert(mTokenStorage.mt_ReserveCashNotAvailable.selector);
        mWeth.reduceReserves(20 ether);
    }
}
