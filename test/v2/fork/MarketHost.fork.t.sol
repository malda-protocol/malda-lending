// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Operator} from "src/Operator/Operator.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mToken} from "src/mToken/mToken.sol";
import {mTokenConfiguration} from "src/mToken/mTokenConfiguration.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

interface IWETH {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MarketHostForkTest is BaseForkTest {
    // ---------- Constants ----------
    address internal constant LINEA_WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address internal constant MALDA_WETH_MARKET = 0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99;

    // A Linea address with a large WETH balance at our pinned fork block (used to fund the test user).
    address internal constant LINEA_WETH_HOLDER = 0x90E8a5b881D211f418d77Ba8978788b62544914B;

    address internal ownerOnChain;

    JumpRateModelV4 internal newInterestModel;
    mErc20Host internal market;
    IERC20 internal asset;

    function setUp() public override {
        super.setUp();

        lineaFork = vm.createSelectFork(vm.envString("LINEA_RPC_URL"), 24_326_770);
        _selectLineaFork();

        market = mErc20Host(MALDA_WETH_MARKET);
        asset = IERC20(market.underlying());
        assertEq(address(asset), LINEA_WETH, "test market underlying is not WETH");

        ownerOnChain = market.admin();

        // Matches the parameters used in earlier marketHost integration tests.
        newInterestModel =
            new JumpRateModelV4(31_536_000, 0, 2_219_685_438, 95_129_375_951, 0.4e18, address(this), "TEST");
    }

    ////////////////////////////////////////////////////////////
    //                  SetInterestRateModel                  //
    ////////////////////////////////////////////////////////////

    function test_fork_accrueInterest_revertsWith_mt_BorrowRateTooHigh_whenInterestRateModelTooHigh() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 borrowRateMaxMantissa = mTokenStorage(address(market)).borrowRateMaxMantissa();

        // Construct a model that is guaranteed to exceed the current max borrow rate even at 0% utilization.
        JumpRateModelV4 tooHighModel =
            new JumpRateModelV4(31_536_000, borrowRateMaxMantissa + 1, 1, 1, 0.8e18, address(this), "TOO_HIGH_MODEL");

        // this should not revert; the revert we care about is `accrueInterest()`.
        vm.prank(ownerOnChain);
        mTokenConfiguration(address(market)).setInterestRateModel(address(tooHighModel));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mTokenConfiguration(address(market)).interestRateModel(),
            address(tooHighModel),
            "interest rate model was not updated to the too-high model"
        );

        // Force an interest accrual path to run (this market uses timestamps, and accrual is skipped if "fresh").
        vm.warp(block.timestamp + 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_BorrowRateTooHigh.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mTokenStorage(address(market)).accrueInterest();
    }

    function test_fork_setInterestRateModel_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address oldInterestRateModel = mTokenConfiguration(address(market)).interestRateModel();

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market)).setBorrowRateMaxMantissa(1e18);
        vm.warp(block.timestamp + 1);
        mTokenStorage(address(market)).accrueInterest(); // ensure the next `setInterestRateModel` does not emit AccrueInterest

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(market));
        emit mTokenStorage.NewMarketInterestRateModel(oldInterestRateModel, address(newInterestModel));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mTokenConfiguration(address(market)).setInterestRateModel(address(newInterestModel));
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mTokenConfiguration(address(market)).interestRateModel(),
            address(newInterestModel),
            "interest rate model was not updated"
        );
    }

    ////////////////////////////////////////////////////////////
    //                         Borrow                         //
    ////////////////////////////////////////////////////////////

    function test_fork_borrow_success_safeZonePoc() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address borrower = users.alice;

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market)).setBorrowRateMaxMantissa(1e18);
        mTokenConfiguration(address(market)).setInterestRateModel(address(newInterestModel));

        address operatorAddr = market.operator();
        Operator(operatorAddr).setWhitelistedUser(borrower, true);
        vm.stopPrank();

        _disableOperatorFirewall(operatorAddr);

        uint256 minBorrowSize = Operator(operatorAddr).minBorrowSize(address(market));
        uint256 borrowAmount = minBorrowSize + 1;
        uint256 supplyAmount = borrowAmount * 20;

        _fundUserWithWeth(borrower, supplyAmount);

        vm.startPrank(borrower);
        IWETH(LINEA_WETH).approve(address(market), supplyAmount);
        market.mint(supplyAmount, borrower, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);
        mTokenStorage(address(market)).accrueInterest(); // keep the borrow call "fresh" so the next event is Borrow

        uint256 accountBorrowsBefore = market.borrowBalanceStored(borrower);
        uint256 totalBorrowsBefore = mToken(address(market)).totalBorrows();
        uint256 underlyingBalanceBefore = IWETH(LINEA_WETH).balanceOf(borrower);
        uint256 borrowRateBefore = mToken(address(market)).borrowRatePerBlock();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(market));
        emit mTokenStorage.Borrow(
            borrower, borrowAmount, accountBorrowsBefore + borrowAmount, totalBorrowsBefore + borrowAmount
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(borrower);
        market.borrow(borrowAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            market.borrowBalanceStored(borrower),
            accountBorrowsBefore + borrowAmount,
            "borrow balance did not increase by borrowAmount"
        );
        assertEq(
            IWETH(LINEA_WETH).balanceOf(borrower),
            underlyingBalanceBefore + borrowAmount,
            "borrower did not receive the borrowed WETH"
        );

        uint256 borrowRateAfter = mToken(address(market)).borrowRatePerBlock();
        assertGe(borrowRateAfter, borrowRateBefore, "borrow rate did not increase after utilization increased");

        uint256 cash = mToken(address(market)).getCash();
        uint256 totalBorrows = mToken(address(market)).totalBorrows();
        uint256 totalReserves = mToken(address(market)).totalReserves();
        uint256 utilization = newInterestModel.utilizationRate(cash, totalBorrows, totalReserves);

        assertLe(utilization, 1e18, "utilization exceeded 100% after borrow");
    }

    function test_fork_borrow_success_safeZonePoc_whenMultipleSuppliers() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address operatorAddr = market.operator();
        uint256 minBorrowSize = Operator(operatorAddr).minBorrowSize(address(market));
        uint256 borrowAmount = minBorrowSize + 1;

        // Keep this safe even if minBorrowSize changes.
        require(borrowAmount <= type(uint256).max / 100, "borrowAmount too large");

        uint256 supplierSupply = borrowAmount * 100;
        uint256 borrowerSupply = borrowAmount * 50;

        address borrower1 = makeAddr("Borrower1");
        address borrower2 = makeAddr("Borrower2");
        address supplier1 = makeAddr("Supplier1");
        address supplier2 = makeAddr("Supplier2");
        address supplier3 = makeAddr("Supplier3");

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market)).setBorrowRateMaxMantissa(1e18);
        mTokenConfiguration(address(market)).setInterestRateModel(address(newInterestModel));

        Operator(operatorAddr).setWhitelistedUser(borrower1, true);
        Operator(operatorAddr).setWhitelistedUser(borrower2, true);
        Operator(operatorAddr).setWhitelistedUser(supplier1, true);
        Operator(operatorAddr).setWhitelistedUser(supplier2, true);
        Operator(operatorAddr).setWhitelistedUser(supplier3, true);
        vm.stopPrank();

        _disableOperatorFirewall(operatorAddr);

        _fundUserWithWeth(supplier1, supplierSupply);
        _fundUserWithWeth(supplier2, supplierSupply);
        _fundUserWithWeth(supplier3, supplierSupply);

        _fundUserWithWeth(borrower1, borrowerSupply);
        _fundUserWithWeth(borrower2, borrowerSupply);

        vm.startPrank(supplier1);
        IWETH(LINEA_WETH).approve(address(market), supplierSupply);
        market.mint(supplierSupply, supplier1, 0);
        vm.stopPrank();

        vm.startPrank(supplier2);
        IWETH(LINEA_WETH).approve(address(market), supplierSupply);
        market.mint(supplierSupply, supplier2, 0);
        vm.stopPrank();

        vm.startPrank(supplier3);
        IWETH(LINEA_WETH).approve(address(market), supplierSupply);
        market.mint(supplierSupply, supplier3, 0);
        vm.stopPrank();

        vm.startPrank(borrower1);
        IWETH(LINEA_WETH).approve(address(market), borrowerSupply);
        market.mint(borrowerSupply, borrower1, 0);
        vm.stopPrank();

        vm.startPrank(borrower2);
        IWETH(LINEA_WETH).approve(address(market), borrowerSupply);
        market.mint(borrowerSupply, borrower2, 0);
        vm.stopPrank();

        vm.warp(block.timestamp + 1);
        mTokenStorage(address(market)).accrueInterest(); // keep borrow calls "fresh"

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        uint256 accountBorrowsBefore1 = market.borrowBalanceStored(borrower1);
        uint256 totalBorrowsBefore1 = mToken(address(market)).totalBorrows();
        vm.expectEmit(true, false, false, true, address(market));
        emit mTokenStorage.Borrow(
            borrower1, borrowAmount, accountBorrowsBefore1 + borrowAmount, totalBorrowsBefore1 + borrowAmount
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(borrower1);
        market.borrow(borrowAmount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        uint256 accountBorrowsBefore2 = market.borrowBalanceStored(borrower2);
        uint256 totalBorrowsBefore2 = mToken(address(market)).totalBorrows();
        vm.expectEmit(true, false, false, true, address(market));
        emit mTokenStorage.Borrow(
            borrower2, borrowAmount, accountBorrowsBefore2 + borrowAmount, totalBorrowsBefore2 + borrowAmount
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(borrower2);
        market.borrow(borrowAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            market.borrowBalanceStored(borrower1),
            accountBorrowsBefore1 + borrowAmount,
            "borrower1 borrow balance did not increase by borrowAmount"
        );
        assertEq(
            market.borrowBalanceStored(borrower2),
            accountBorrowsBefore2 + borrowAmount,
            "borrower2 borrow balance did not increase by borrowAmount"
        );

        uint256 cash = mToken(address(market)).getCash();
        uint256 totalBorrows = mToken(address(market)).totalBorrows();
        uint256 totalReserves = mToken(address(market)).totalReserves();
        uint256 utilization = newInterestModel.utilizationRate(cash, totalBorrows, totalReserves);

        assertLe(utilization, 1e18, "utilization exceeded 100% after borrows");
        assertLt(utilization, 0.5e18, "expected utilization to remain below 50% in safe-zone setup");
    }

    function test_fork_borrow_revertsWith_Operator_InsufficientLiquidity() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address borrower = users.alice;

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market)).setBorrowRateMaxMantissa(1e18);
        mTokenConfiguration(address(market)).setInterestRateModel(address(newInterestModel));

        address operatorAddr = market.operator();
        Operator(operatorAddr).setWhitelistedUser(borrower, true);
        vm.stopPrank();

        _disableOperatorFirewall(operatorAddr);

        uint256 minBorrowSize = Operator(operatorAddr).minBorrowSize(address(market));
        uint256 supplyAmount = (minBorrowSize + 1) * 5;

        _fundUserWithWeth(borrower, supplyAmount);

        vm.startPrank(borrower);
        IWETH(LINEA_WETH).approve(address(market), supplyAmount);
        market.mint(supplyAmount, borrower, 0);
        vm.stopPrank();

        // Try to borrow more than the available cash in the market.
        uint256 cash = mToken(address(market)).getCash();
        uint256 overBorrowAmount = cash + 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(bytes("Operator_InsufficientLiquidity()"));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(borrower);
        market.borrow(overBorrowAmount);
    }

    ////////////////////////////////////////////////////////////
    //                    UtilizationRate                     //
    ////////////////////////////////////////////////////////////

    function test_fork_utilizationRate_success_thinLiquidityPoc() public view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 cash = mToken(address(market)).getCash();
        uint256 totalBorrows = mToken(address(market)).totalBorrows();
        uint256 totalReserves = mToken(address(market)).totalReserves();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 utilization = JumpRateModelV4(mToken(address(market)).interestRateModel())
            .utilizationRate(cash, totalBorrows, totalReserves);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertLe(utilization, 1e18, "utilization should never exceed 100%");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _fundUserWithWeth(address recipient, uint256 amount) internal {
        _fundErc20FromHolder(LINEA_WETH, LINEA_WETH_HOLDER, recipient, amount);
    }

    function _disableOperatorFirewall(address operatorAddr) internal {
        // The deployed Linea Operator implementation enforces Hypernative firewall context checks that
        // are not satisfiable on a fork without Hypernative consumer registration. Disable the firewall
        // for deterministic fork tests.
        address firewallAdmin = Operator(operatorAddr).hypernativeFirewallAdmin();

        vm.prank(firewallAdmin);
        Operator(operatorAddr).setFirewall(address(0));
    }
}
