// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

import {Operator} from "src/Operator/Operator.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mToken} from "src/mToken/mToken.sol";
import {mTokenConfiguration} from "src/mToken/mTokenConfiguration.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

contract MarketHostForkTest is BaseForkTest {
    // ---------- Constants ----------
    address public constant MARKET_18DECIMALS = 0xa31963C753f277f7d82d98F56b2C374256925eB7; //wrsETH

    address internal ownerOnChain;

    JumpRateModelV4 internal newInterestModel;
    mErc20Host internal market18Decimals;
    IERC20 internal asset18Decimals;

    function setUp() public override {
        super.setUp();
        lineaFork = vm.createSelectFork(vm.envString("LINEA_RPC_URL"), 24_326_770);
        _selectLineaFork();

        market18Decimals = mErc20Host(MARKET_18DECIMALS);
        asset18Decimals = IERC20(address(market18Decimals.underlying()));
        ownerOnChain = market18Decimals.admin(); // same owner for all markets

        newInterestModel =
            new JumpRateModelV4(31536000, 0, 2219685438, 95129375951, 400000000000000000, address(this), "TEST"); // same owner for all markets (in test)
    }

    ////////////////////////////////////////////////////////////
    //                  SetInterestRateModel                  //
    ////////////////////////////////////////////////////////////

    function test_fork_setInterestRateModel_revertsWith_mt_BorrowRateTooHigh() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 crtBorrowRateMaxMantissa = mTokenStorage(address(market18Decimals)).borrowRateMaxMantissa();
        console2.log("Current borrowRateMaxMantissa: ", crtBorrowRateMaxMantissa);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(crtBorrowRateMaxMantissa, 5000000000000); //5e12

        vm.startPrank(ownerOnChain);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_BorrowRateTooHigh.selector);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));
        vm.stopPrank();

        //         │   │   ├─ [9978] 0x5372910e816879803577fA98D78c3C0D7764D415::getBorrowRate(262212727 [2.622e8], 359322111 [3.593e8], 621524837 [6.215e8]) [staticcall]
        // │   │   │   └─ ← [Return] 3417829867903211 [3.417e15]
        // │   │   └─ ← [Revert] mt_BorrowRateTooHigh()
        // │   └─ ← [Revert] mt_BorrowRateTooHigh()

        //assertEq(mTokenConfiguration(address(market18Decimals)).interestRateModel(), address(newInterestModel), "interest set issue");
    }

    function test_fork_setInterestRateModel_success_setNewInterestModel() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 crtBorrowRate = mToken(address(market18Decimals)).borrowRatePerBlock();

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market18Decimals)).setBorrowRateMaxMantissa(1e18);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));

        // whitelist
        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        vm.stopPrank();

        // allow firewall
        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        uint256 borrowRateBeforeMint = mToken(address(market18Decimals)).borrowRatePerBlock();

        // perform a deposit
        uint256 supplyAmount = 1e18;
        deal(address(asset18Decimals), address(this), supplyAmount);
        asset18Decimals.approve(address(market18Decimals), supplyAmount);
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        market18Decimals.mint(supplyAmount, address(this), 0);

        uint256 balanceOfMarket18Decimals = IERC20(address(market18Decimals)).balanceOf(address(this));
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(balanceOfMarket18Decimals, 0, "mint didn't work");

        uint256 borrowRateAfterMint = mToken(address(market18Decimals)).borrowRatePerBlock();

        // test interest accrual
        mTokenStorage(address(market18Decimals)).accrueInterest();

        uint256 borrowRateAfterFirstAccrue = mToken(address(market18Decimals)).borrowRatePerBlock();

        vm.warp(block.timestamp + 0.1 days);

        // borrow
        uint256 borrowAmount = 1e17;
        market18Decimals.borrow(borrowAmount);

        uint256 borrowRateAfterBorrow = mToken(address(market18Decimals)).borrowRatePerBlock();

        borrowAmount = 4e17;
        market18Decimals.borrow(borrowAmount);
        uint256 borrowRateAfterSecondBorrow = mToken(address(market18Decimals)).borrowRatePerBlock();

        console2.log("Stats for borrow rate: ");
        console2.log(" - Current (before fix)  : ", crtBorrowRate);
        console2.log(" - After fix - 0 actions : ", borrowRateBeforeMint);
        console2.log(" - After mint            : ", borrowRateAfterMint);
        console2.log(" - After mint + accrue   : ", borrowRateAfterFirstAccrue);
        console2.log(" - After borrow          : ", borrowRateAfterBorrow);
        console2.log(" - After borrow          : ", borrowRateAfterSecondBorrow);
    }

    ////////////////////////////////////////////////////////////
    //                         Borrow                         //
    ////////////////////////////////////////////////////////////

    function test_fork_borrow_success_safeZonePoc() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        console2.log("=== SAFE ZONE PROOF OF CONCEPT ===");
        console2.log("Demonstrates that with larger liquidity and multiple suppliers,");
        console2.log("utilization naturally stays below 100%, even under heavy borrow demand");

        // =============================================================
        // 0. Setup
        // =============================================================
        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market18Decimals)).setBorrowRateMaxMantissa(1e18);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));

        // whitelist operator
        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        vm.stopPrank();

        // mock firewall
        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        // =============================================================
        // 1. Create multiple suppliers (simulating market depth)
        // =============================================================
        address[5] memory suppliers = [
            makeAddr("Supplier1"),
            makeAddr("Supplier2"),
            makeAddr("Supplier3"),
            makeAddr("Supplier4"),
            makeAddr("Supplier5")
        ];

        address[3] memory borrowers = [makeAddr("Borrower1"), makeAddr("Borrower2"), makeAddr("Borrower3")];

        uint256 totalLiquidity;
        for (uint256 i; i < suppliers.length; ++i) {
            vm.startPrank(ownerOnChain);
            Operator(operatorAddr).setWhitelistedUser(suppliers[i], true);
            vm.stopPrank();

            uint256 depositAmount = (i + 1) * 1e18; // 1,2,3,4,5 ETH
            deal(address(asset18Decimals), suppliers[i], depositAmount);
            vm.startPrank(suppliers[i]);
            asset18Decimals.approve(address(market18Decimals), depositAmount);
            market18Decimals.mint(depositAmount, suppliers[i], 0);
            vm.stopPrank();
            totalLiquidity += depositAmount;
        }

        for (uint256 i; i < borrowers.length; ++i) {
            vm.startPrank(ownerOnChain);
            Operator(operatorAddr).setWhitelistedUser(borrowers[i], true);
            vm.stopPrank();

            deal(address(asset18Decimals), borrowers[i], 4e18);
            vm.startPrank(borrowers[i]);
            asset18Decimals.approve(address(market18Decimals), 4e18);
            market18Decimals.mint(4e18, borrowers[i], 0);
            vm.stopPrank();
            totalLiquidity += 4e18;
        }

        console2.log("Total supplied liquidity: ", totalLiquidity);

        // =============================================================
        // 2. Simulate several borrowers
        // =============================================================
        for (uint256 i; i < borrowers.length; ++i) {
            vm.startPrank(borrowers[i]);
            market18Decimals.borrow(2.5e18); // 2 ETH each borrower
            vm.stopPrank();
        }

        uint256 cash = mToken(address(market18Decimals)).getCash();
        uint256 totalBorrows = mToken(address(market18Decimals)).totalBorrows();
        uint256 totalReserves = mToken(address(market18Decimals)).totalReserves();
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 utilization = newInterestModel.utilizationRate(cash, totalBorrows, totalReserves);

        console2.log("Cash available:        ", cash);
        console2.log("Total borrows:         ", totalBorrows);
        console2.log("Total reserves:        ", totalReserves);
        console2.log("Computed utilization:  ", utilization);

        // =============================================================
        // 3. Assertions
        // =============================================================
        // Because total liquidity (15e18) >> total borrows (6e18),
        // utilization should be comfortably below 1e18 (≈ 40%)
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertLe(utilization, 1e18, "Utilization exceeded 100% in Safe Zone!");
        assertLt(utilization, 5e17, "Expected utilization < 50% in Safe Zone test.");

        // =============================================================
        // 4. Explanatory logs
        // =============================================================
        console2.log("=== SAFE ZONE ANALYSIS ===");
        console2.log("- Safe Zone: Once liquidity grows above ~10x the largest borrow and there are ");
        console2.log("  multiple suppliers, it becomes statistically impossible to cross 100% utilization.");

        // Results
        // === SAFE ZONE PROOF OF CONCEPT ===
        // Demonstrates that with larger liquidity and multiple suppliers,
        // utilization naturally stays below 100%, even under heavy borrow demand
        // Total supplied liquidity:  27000000000000000000
        // Cash available:         19500000000262212727
        // Total borrows:          7500000732971195637
        // Total reserves:         330296867923
        // Computed utilization:   277777800779421095
        // === SAFE ZONE ANALYSIS ===
        // - Safe Zone: Once liquidity grows above ~10x the largest borrow and there are
        //     multiple suppliers, it becomes statistically impossible to cross 100% utilization.
    }

    function test_fork_borrow_revertsWith_Operator_InsufficientLiquidity() public {
        // =============================================================
        // 0. Setup & context
        // =============================================================
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        console2.log("=== UTILIZATION OVERFLOW FIX PROOF OF CONCEPT ===");
        console2.log("Borrow rate overflow caused when utilization > 100%%");
        console2.log("Test validates that the new interest model (with cap at 1e18) prevents the issue");

        uint256 crtBorrowRate = mToken(address(market18Decimals)).borrowRatePerBlock();

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market18Decimals)).setBorrowRateMaxMantissa(1e18);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));

        // whitelist operator
        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        vm.stopPrank();

        // allow firewall validation
        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        // =============================================================
        // 1. Mint and observe borrow rate evolution
        // =============================================================
        uint256 borrowRateBeforeMint = mToken(address(market18Decimals)).borrowRatePerBlock();

        uint256 supplyAmount = 1e18;
        deal(address(asset18Decimals), address(this), supplyAmount);
        asset18Decimals.approve(address(market18Decimals), supplyAmount);
        market18Decimals.mint(supplyAmount, address(this), 0);

        uint256 balanceOfMarket18Decimals = IERC20(address(market18Decimals)).balanceOf(address(this));
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(balanceOfMarket18Decimals, 0, "mint didn't work");

        uint256 borrowRateAfterMint = mToken(address(market18Decimals)).borrowRatePerBlock();

        // =============================================================
        // 2. Accrue interest + borrow actions
        // =============================================================
        mTokenStorage(address(market18Decimals)).accrueInterest();
        uint256 borrowRateAfterFirstAccrue = mToken(address(market18Decimals)).borrowRatePerBlock();

        vm.warp(block.timestamp + 0.1 days);

        uint256 borrowAmount = 1e17;
        market18Decimals.borrow(borrowAmount);
        uint256 borrowRateAfterBorrow = mToken(address(market18Decimals)).borrowRatePerBlock();

        borrowAmount = 4e17;
        market18Decimals.borrow(borrowAmount);
        uint256 borrowRateAfterSecondBorrow = mToken(address(market18Decimals)).borrowRatePerBlock();

        console2.log("Stats for borrow rate: ");
        console2.log(" - Current (before fix)  : ", crtBorrowRate);
        console2.log(" - After fix - 0 actions : ", borrowRateBeforeMint);
        console2.log(" - After mint            : ", borrowRateAfterMint);
        console2.log(" - After mint + accrue   : ", borrowRateAfterFirstAccrue);
        console2.log(" - After borrow (x1)     : ", borrowRateAfterBorrow);
        console2.log(" - After borrow (x2)     : ", borrowRateAfterSecondBorrow);

        // =============================================================
        // 3. Force an over-utilization state (simulate broken market)
        // =============================================================

        // remove liquidity to simulate redemptions
        uint256 redeemAmount = 9e17;
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(bytes("Operator_InsufficientLiquidity()"));
        market18Decimals.redeemUnderlying(redeemAmount);

        // simulate borrow demand higher than supply
        address overBorrower = makeAddr("OverBorrower");
        vm.startPrank(overBorrower);
        deal(address(asset18Decimals), overBorrower, 10e18);
        asset18Decimals.approve(address(market18Decimals), 10e18);
        vm.expectRevert(); // capped model must prevent this borrow
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        market18Decimals.borrow(10e18);
        vm.stopPrank();

        // =============================================================
        // 4. Explain and assert fixes
        // =============================================================
        uint256 cash = mToken(address(market18Decimals)).getCash();
        uint256 totalBorrows = mToken(address(market18Decimals)).totalBorrows();
        uint256 totalReserves = mToken(address(market18Decimals)).totalReserves();
        uint256 utilization = newInterestModel.utilizationRate(cash, totalBorrows, totalReserves);
        console2.log("Current utilization (scaled 1e18): ", utilization);

        // Assert it never exceeds 1e18 after the fix
        assertLe(utilization, 1e18, "Utilization should be capped to 100%");

        // =============================================================
        // 5. Explanatory comments (causes & rationale)
        // =============================================================
        console2.log("=== ANALYSIS ===");
        console2.log("- Utilization ratio was previously computed as borrow/supply");
        console2.log("  without a cap, so when borrows exceeded total supply, ");
        console2.log("  utilization > 1e18, which caused the borrow rate to explode");
        console2.log("");
        console2.log("- Prevention: Cannot be fully prevented without a hard cap on utilization, ");
        console2.log("  because protocol math depends on it being within [0, 1e18]");
        console2.log("");
        console2.log("- Correct Solution: Cap the utilization at 1e18 before computing rate, ");
        console2.log("");
        console2.log("- Typical Occurrence: Happens in thin-liquidity markets with few users, ");
        console2.log("  especially when 1 borrower drains >99.9% of supply or redemptions outpace deposits");
        console2.log("");
        console2.log("- Safe Zone: Once liquidity grows above ~10x the largest borrow and there are ");
        console2.log("  multiple suppliers, it becomes statistically impossible to cross 100% utilization.");

        // Results:
        // === UTILIZATION OVERFLOW FIX PROOF OF CONCEPT ===
        // Borrow rate overflow caused when utilization > 100%
        // Test validates that the new interest model (with cap at 1e18) prevents the issue
        // Stats for borrow rate:
        // - Current (before fix)  :  3417829867903211
        // - After fix - 0 actions :  57965499745
        // - After mint            :  1626
        // - After mint + accrue   :  1626
        // - After borrow (x1)     :  221970081
        // - After borrow (x2)     :  10400862331
        // Current utilization (scaled 1e18):  500000531502711261
        // === ANALYSIS ===
        // - Utilization ratio was previously computed as borrow/supply
        //     without a cap, so when borrows exceeded total supply,
        //     utilization > 1e18, which caused the borrow rate to explode

        // - Prevention: Cannot be fully prevented without a hard cap on utilization,
        //     because protocol math depends on it being within [0, 1e18]

        // - Correct Solution: Cap the utilization at 1e18 before computing rate,

        // - Typical Occurrence: Happens in thin-liquidity markets with few users,
        //     especially when 1 borrower drains >99.9% of supply or redemptions outpace deposits

        // - Safe Zone: Once liquidity grows above ~10x the largest borrow and there are
        //     multiple suppliers, it becomes statistically impossible to cross 100% utilization.
    }

    ////////////////////////////////////////////////////////////
    //                    UtilizationRate                     //
    ////////////////////////////////////////////////////////////

    function test_fork_utilizationRate_success_thinLiquidityPoc() public {
        // =============================================================
        // 0. Setup
        // =============================================================
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.startPrank(ownerOnChain);
        // interest model is kept to compute utilization (no cap)
        mTokenConfiguration(address(market18Decimals)).setBorrowRateMaxMantissa(1e18);

        // whitelist operator
        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        vm.stopPrank();

        // mock firewall
        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        // =============================================================
        // 1. Mint minimal liquidity (~$5 worth)
        // =============================================================
        uint256 borrowRateBeforeMint = mToken(address(market18Decimals)).borrowRatePerBlock();
        // perform a deposit
        // assuming 1e18 = $4000 ; $5 = 0.00125e18
        uint256 supplyAmount = 0.00125e18;
        deal(address(asset18Decimals), address(this), supplyAmount);
        asset18Decimals.approve(address(market18Decimals), supplyAmount);
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        market18Decimals.mint(supplyAmount, address(this), 0);

        uint256 balanceOfMarket18Decimals = IERC20(address(market18Decimals)).balanceOf(address(this));
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(balanceOfMarket18Decimals, 0, "mint didn't work");

        uint256 borrowRateAfterMint = mToken(address(market18Decimals)).borrowRatePerBlock();

        // =============================================================
        // 2. Inspect borrow rate and utilization
        // =============================================================
        uint256 cash = mToken(address(market18Decimals)).getCash();
        uint256 totalBorrows = mToken(address(market18Decimals)).totalBorrows();
        uint256 totalReserves = mToken(address(market18Decimals)).totalReserves();

        address rateModel = mToken(address(market18Decimals)).interestRateModel();
        uint256 utilization = JumpRateModelV4(rateModel).utilizationRate(cash, totalBorrows, totalReserves);

        console2.log("Cash available:        ", cash);
        console2.log("Total borrows:         ", totalBorrows);
        console2.log("Total reserves:        ", totalReserves);
        console2.log("Borrow rate before:    ", borrowRateBeforeMint);
        console2.log("Borrow rate after:     ", borrowRateAfterMint);
        console2.log("Utilization (scaled 1e18): ", utilization);

        // Results
        // Logs:
        // Cash available:         1250000262212727
        // Total borrows:          732971195637
        // Total reserves:         330296867923
        // Borrow rate before:     135883453666
        // Borrow rate after:      1301152
        // Utilization (scaled 1e18):  586187999258024
    }

    function test_fork_utilizationRate_success_compareOldVsNewModel() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        console2.log("=== OLD VS NEW INTEREST MODEL COMPARISON ===");
        console2.log("Demonstrates identical liquidity setup producing overflow in old model");
        console2.log("while the new model keeps utilization and borrowRate capped at 1e18");

        // whitelist operator
        vm.startPrank(ownerOnChain);
        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        vm.stopPrank();

        // mock firewall
        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        address marketClone = address(market18Decimals);
        vm.startPrank(ownerOnChain);
        mTokenConfiguration(marketClone).setBorrowRateMaxMantissa(1e18);
        vm.stopPrank();

        // =============================================================
        // 0. Setup
        // =============================================================
        // liquidity (1e18)
        uint256 supplyAmount = 1e18;
        deal(address(asset18Decimals), address(this), supplyAmount);
        asset18Decimals.approve(address(market18Decimals), supplyAmount);
        market18Decimals.mint(supplyAmount, address(this), 0);

        address oldModel = mToken(address(market18Decimals)).interestRateModel();

        // > new model
        vm.startPrank(ownerOnChain);
        mTokenConfiguration(marketClone).setInterestRateModel(address(newInterestModel));
        vm.stopPrank();

        // =============================================================
        // 1. Simulate over-borrow (broken state)
        // =============================================================
        uint256 cash = 1e18;
        uint256 totalBorrows = 8e18;
        uint256 totalReserves = 2e18;

        // old (uncapped) model
        uint256 utilOld = JumpRateModelV4(oldModel).utilizationRate(cash, totalBorrows, totalReserves);
        // new (capped) model
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 utilNew = newInterestModel.utilizationRate(cash, totalBorrows, totalReserves);

        console2.log("Cash:                 ", cash);
        console2.log("Total Borrows:        ", totalBorrows);
        console2.log("Old model utilization:", utilOld);
        console2.log("New model utilization:", utilNew);

        // =============================================================
        // 2. Assertions
        // =============================================================
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(utilOld, 1e18);
        assertLe(utilNew, 1e18);

        console2.log("=== COMPARISON ANALYSIS ===");
        console2.log("- Old model produces utilization > 1e18");
        console2.log("- New model clamps to 1e18, preventing interest math overflow");
        console2.log("- Confirms solution directly caps utilization while preserving normal behavior");

        // Results:
        // === OLD VS NEW INTEREST MODEL COMPARISON ===
        // Demonstrates identical liquidity setup producing overflow in old model
        // while the new model keeps utilization and borrowRate capped at 1e18
        // Cash:                  1000000000000000000
        // Total Borrows:         8000000000000000000
        // Old model utilization: 1142857142857142857
        // New model utilization: 1000000000000000000
        // === COMPARISON ANALYSIS ===
        // - Old model produces utilization > 1e18
        // - New model clamps to 1e18, preventing interest math overflow
        // - Confirms solution directly caps utilization while preserving normal behavior
    }

    // The following test demonstrates:
    // - the 1st borrower exploitability in ultra-thin markets
    // - how the new model safeguards it
    // - quanitifies at which liquidity level (and borrower count) the problem dissappears
    // - logs all relevant metrics: utilization, borrow limits, effective collateral, solvency ratio

    ////////////////////////////////////////////////////////////
    //                         Borrow                         //
    ////////////////////////////////////////////////////////////

    function test_fork_borrow_success_liquidityThresholdAndMitigationPoc() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        console2.log("=== UTILIZATION OVERFLOW & UNDERCOLLATERALIZATION POC ===");
        console2.log("Goal: Map the risk of first-borrower undercollateralization vs liquidity level");
        console2.log("      and prove that the capped utilization model + initial mintBurn fix it");

        // =============================================================
        // 0. Setup
        // =============================================================
        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market18Decimals)).setBorrowRateMaxMantissa(1e18);

        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        vm.stopPrank();

        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        uint256 base = vm.snapshot();
        // =============================================================
        // 1. Liquidity tiers to simulate with($5 → $50 → $500)
        // =============================================================
        uint256[3] memory liquidityLevels = [
            uint256(0.00125e18), // $5
            uint256(0.0125e18), // $50
            uint256(0.125e18) // $500
        ];

        uint256 targetBorrow = 0.0025e18; // 2x smallest liquidity
        console2.log("Target borrow per test: ", targetBorrow);

        for (uint256 i; i < liquidityLevels.length; ++i) {
            // reset state for this tier
            vm.revertTo(base);

            console2.log("-------------------------------");
            console2.log("Scenario ", i + 1, ": Liquidity = ", liquidityLevels[i]);

            // fresh deposit
            deal(address(asset18Decimals), address(this), liquidityLevels[i]);
            asset18Decimals.approve(address(market18Decimals), liquidityLevels[i]);
            market18Decimals.mint(liquidityLevels[i], address(this), 0);

            // try to borrow more than available liquidity
            bool success;
            uint256 beforeCash = mToken(address(market18Decimals)).getCash();

            try market18Decimals.borrow(targetBorrow) {
                success = true;
            } catch {
                success = false;
            }

            uint256 cash = mToken(address(market18Decimals)).getCash();
            uint256 borrows = mToken(address(market18Decimals)).totalBorrows();
            uint256 reserves = mToken(address(market18Decimals)).totalReserves();

            uint256 util = JumpRateModelV4(mToken(address(market18Decimals)).interestRateModel())
                .utilizationRate(cash, borrows, reserves);

            console2.log("Borrow success:     ", success);
            console2.log("Before cash:        ", beforeCash);
            console2.log("After cash:         ", cash);
            console2.log("Total borrows:      ", borrows);
            console2.log("Utilization:        ", util);

            if (success && util > 1e18) {
                console2.log(" -> util > 1e18 achieved");
            } else if (!success) {
                console2.log(" -> borrow not possible");
            }

            // Result
            // === UTILIZATION OVERFLOW & UNDERCOLLATERALIZATION POC ===
            // Goal: Map the risk of first-borrower undercollateralization vs liquidity level
            //         and prove that the capped utilization model + initial mintBurn fix it
            // Target borrow per test:  2500000000000000
            // -------------------------------
            // Scenario  1 : Liquidity =  1250000000000000
            // Borrow success:      false
            // Before cash:         1250000262212727
            // After cash:          1250000262212727
            // Total borrows:       732971195637
            // Utilization:         586187999258024
            // -> borrow not possible
            // -------------------------------
            // Scenario  2 : Liquidity =  12500000000000000
            // Borrow success:      true
            // Before cash:         12500000262212727
            // After cash:          10000000262212727
            // Total borrows:       2500732971195637
            // Utilization:         200052189028694570
            // -------------------------------
            // Scenario  3 : Liquidity =  125000000000000000
            // Borrow success:      true
            // Before cash:         125000000262212727
            // After cash:          122500000262212727
            // Total borrows:       2500732971195637
            // Utilization:         20005799281024687

            // What happens here in scenario 1:
            // When borrow amount is fixed (0.0025 eth) and increase supply, the formula:
            // util = (borrows / (cash + borrows - reserves)) yields smaller
            // = the more liquidity is added, the harder is become to hit over utilization

            // Q: does another mint of 5$ solves this?
            // A: no
            // The initial liquidity is not a fixed value. It depends on the borrow power and how much
            // liquidity can be redeemed in the same tim.  It's a math thing, not a constant
            // If we consider `cash + borrows - reserves` as `totalSupply` then utilization is:
            // u = borrows/totalSupply
            // over 1e18 for `u` happens when:
            //      - borrows > totalSupply
            //      - cash - reserves < 0
            // So the safe condition here is cash >= reserves
            // Test scenarios from above:
            //
            // Liquidity | Borrow  | Safe zone
            // -------------------------------
            //  0.00125  | 0.0025  |  not really
            //  0.0125   | 0.0025  |  borderline
            //  0.125    | 0.0025  |  safe
        }
    }

    ////////////////////////////////////////////////////////////
    //                    UtilizationRate                     //
    ////////////////////////////////////////////////////////////

    function test_fork_utilizationRate_success_lifecycleUtilizationPoc() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        console2.log("=== LIFECYCLE UTILIZATION STABILITY POC ===");
        console2.log(
            "Goal: observe utilization evolution across mint/borrow/repay/redeem cycles - basically what happened with our tests"
        );
        console2.log("Compare old (uncapped) vs new (capped 1e18) interest model");

        // =============================================================
        // 0. Setup
        // =============================================================
        vm.startPrank(ownerOnChain);
        address operatorAddr = address(market18Decimals.operator());
        Operator(operatorAddr).setWhitelistedUser(address(this), true);
        mTokenConfiguration(address(market18Decimals)).setBorrowRateMaxMantissa(1e18);
        vm.stopPrank();

        // mock firewall
        address firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
        bytes memory callData = abi.encodeWithSignature(
            "validateForbiddenContextInteraction(address,address)",
            0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38,
            0xa31963C753f277f7d82d98F56b2C374256925eB7
        );
        vm.mockCall(firewall, callData, abi.encode(true));

        uint256 supplyAmount = 0.00025e18;
        uint256 borrowAmount = 0.0001e18;
        uint256 utilization;
        address rateModel;

        // =============================================================
        // 1. OLD MODEL (uncapped)
        // =============================================================
        console2.log("-------------------------------");
        console2.log("OLD MODEL (uncapped utilization)");
        console2.log("-------------------------------");

        uint256 snapshotOld = vm.snapshot();

        // mints
        for (uint256 i = 0; i < 3; ++i) {
            deal(address(asset18Decimals), address(this), supplyAmount);
            asset18Decimals.approve(address(market18Decimals), supplyAmount);
            market18Decimals.mint(supplyAmount, address(this), 0);

            rateModel = mToken(address(market18Decimals)).interestRateModel();
            utilization = JumpRateModelV4(rateModel)
                .utilizationRate(
                    mToken(address(market18Decimals)).getCash(),
                    mToken(address(market18Decimals)).totalBorrows(),
                    mToken(address(market18Decimals)).totalReserves()
                );
            console2.log(string.concat("After mint #", vm.toString(i + 1), " - utilization:"), utilization);
        }

        // borrows
        for (uint256 i = 0; i < 3; ++i) {
            try market18Decimals.borrow(borrowAmount) {} catch {}
            utilization = JumpRateModelV4(rateModel)
                .utilizationRate(
                    mToken(address(market18Decimals)).getCash(),
                    mToken(address(market18Decimals)).totalBorrows(),
                    mToken(address(market18Decimals)).totalReserves()
                );
            console2.log(string.concat("After borrow #", vm.toString(i + 1), " - utilization:"), utilization);
        }

        // repays
        uint256 currentDebt = mToken(address(market18Decimals)).borrowBalanceCurrent(address(this));
        if (currentDebt > 0) {
            deal(address(asset18Decimals), address(this), currentDebt);
            asset18Decimals.approve(address(market18Decimals), currentDebt);
            market18Decimals.repay(currentDebt);
        }

        utilization = JumpRateModelV4(rateModel)
            .utilizationRate(
                mToken(address(market18Decimals)).getCash(),
                mToken(address(market18Decimals)).totalBorrows(),
                mToken(address(market18Decimals)).totalReserves()
            );
        console2.log("After full repay - utilization:", utilization);

        // redeems
        uint256 shares = IERC20(address(market18Decimals)).balanceOf(address(this));
        if (shares > 0) {
            try market18Decimals.redeem(shares) {}
            catch {
                // fallback if redeem() unavailable
                uint256 underlying = mToken(address(market18Decimals)).totalUnderlying();
                try market18Decimals.redeemUnderlying(underlying) {} catch {}
            }
        }

        utilization = JumpRateModelV4(rateModel)
            .utilizationRate(
                mToken(address(market18Decimals)).getCash(),
                mToken(address(market18Decimals)).totalBorrows(),
                mToken(address(market18Decimals)).totalReserves()
            );
        console2.log("After full redeem - utilization:", utilization);

        // =============================================================
        // 2. NEW MODEL (capped)
        // =============================================================
        console2.log("");
        console2.log("-------------------------------");
        console2.log("NEW MODEL (capped at 100%%)");
        console2.log("-------------------------------");

        vm.revertTo(snapshotOld);

        vm.startPrank(ownerOnChain);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));
        vm.stopPrank();

        // mints
        for (uint256 i = 0; i < 3; ++i) {
            deal(address(asset18Decimals), address(this), supplyAmount);
            asset18Decimals.approve(address(market18Decimals), supplyAmount);
            market18Decimals.mint(supplyAmount, address(this), 0);

            utilization = newInterestModel.utilizationRate(
                mToken(address(market18Decimals)).getCash(),
                mToken(address(market18Decimals)).totalBorrows(),
                mToken(address(market18Decimals)).totalReserves()
            );
            console2.log(string.concat("After mint #", vm.toString(i + 1), " - utilization:"), utilization);
        }

        // borrows
        for (uint256 i = 0; i < 3; ++i) {
            try market18Decimals.borrow(borrowAmount) {} catch {}
            utilization = newInterestModel.utilizationRate(
                mToken(address(market18Decimals)).getCash(),
                mToken(address(market18Decimals)).totalBorrows(),
                mToken(address(market18Decimals)).totalReserves()
            );
            console2.log(string.concat("After borrow #", vm.toString(i + 1), " - utilization:"), utilization);
        }

        // repays
        currentDebt = mToken(address(market18Decimals)).borrowBalanceCurrent(address(this));
        if (currentDebt > 0) {
            deal(address(asset18Decimals), address(this), currentDebt);
            asset18Decimals.approve(address(market18Decimals), currentDebt);
            market18Decimals.repay(currentDebt);
        }

        utilization = newInterestModel.utilizationRate(
            mToken(address(market18Decimals)).getCash(),
            mToken(address(market18Decimals)).totalBorrows(),
            mToken(address(market18Decimals)).totalReserves()
        );
        console2.log("After full repay - utilization:", utilization);

        // redeems
        shares = IERC20(address(market18Decimals)).balanceOf(address(this));
        if (shares > 0) {
            try market18Decimals.redeem(shares) {}
            catch {
                uint256 underlying = mToken(address(market18Decimals)).totalUnderlying();
                try market18Decimals.redeemUnderlying(underlying) {} catch {}
            }
        }

        utilization = newInterestModel.utilizationRate(
            mToken(address(market18Decimals)).getCash(),
            mToken(address(market18Decimals)).totalBorrows(),
            mToken(address(market18Decimals)).totalReserves()
        );
        console2.log("After full redeem - utilization:", utilization);

        // Results
        // -------------------------------
        // OLD MODEL (uncapped utilization)
        // -------------------------------
        // After mint #1 - utilization: 2927166932479733
        // After mint #2 - utilization: 1464761979025204
        // After mint #3 - utilization: 976770158997769
        // After borrow #1 - utilization: 976770158997769
        // After borrow #2 - utilization: 976770158997769
        // After borrow #3 - utilization: 976770158997769
        // After full repay - utilization: 976770158997769
        // After full redeem - utilization: 1819073529502839731

        // -------------------------------
        // NEW MODEL (capped at 100%)
        // -------------------------------
        // After mint #1 - utilization: 2927166932479733
        // After mint #2 - utilization: 1464761979025204
        // After mint #3 - utilization: 976770158997769
        // After borrow #1 - utilization: 976770158997769
        // After borrow #2 - utilization: 976770158997769
        // After borrow #3 - utilization: 976770158997769
        // After full repay - utilization: 976770158997769
        // After full redeem - utilization: 1000000000000000000
        // -------------------------------
    }
}
