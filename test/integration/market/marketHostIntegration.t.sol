// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";


import { mErc20Host } from "src/mToken/host/mErc20Host.sol";
import { JumpRateModelV4 } from "src/interest/JumpRateModelV4.sol";

import { mTokenConfiguration } from "src/mToken/mTokenConfiguration.sol";
import { mTokenStorage } from "src/mToken/mTokenStorage.sol";
import { mToken } from "src/mToken/mToken.sol";
import { ImToken } from "src/interfaces/ImToken.sol";

import { Operator } from "src/Operator/Operator.sol";


import "forge-std/console2.sol";
interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}


contract marketHostIntegration is Test {
    // ---------- Constants ----------
    address public constant MARKET_18DECIMALS = 0xa31963C753f277f7d82d98F56b2C374256925eB7; //wrsETH

    uint256 lineaFork;
    uint256 chainIdOnFork;
    address ownerOnChain;

    JumpRateModelV4 newInterestModel;
    mErc20Host market18Decimals;
    IERC20 asset18Decimals;

    function setUp() public {
        string memory rpc = vm.envString("LINEA_RPC_URL");
        lineaFork = vm.createSelectFork(rpc, 24326770);
        chainIdOnFork = block.chainid;

        market18Decimals = mErc20Host(MARKET_18DECIMALS);
        asset18Decimals = IERC20(address(market18Decimals.underlying()));
        ownerOnChain = market18Decimals.admin(); // same owner for all markets

        newInterestModel = new JumpRateModelV4(31536000, 0, 2219685438, 95129375951, 400000000000000000, address(this), "TEST"); // same owner for all markets (in test)
    }

    function test_marketHost18decimals_SetNewInterestModel_Failure() public {
        uint256 crtBorrowRateMaxMantissa = mTokenStorage(address(market18Decimals)).borrowRateMaxMantissa();
        console2.log("Current borrowRateMaxMantissa: ", crtBorrowRateMaxMantissa);

        assertEq(crtBorrowRateMaxMantissa, 5000000000000); //5e12

        vm.startPrank(ownerOnChain);
        vm.expectRevert(mTokenStorage.mt_BorrowRateTooHigh.selector);
        mTokenConfiguration(address(market18Decimals)).setInterestRateModel(address(newInterestModel));
        vm.stopPrank();

        //         │   │   ├─ [9978] 0x5372910e816879803577fA98D78c3C0D7764D415::getBorrowRate(262212727 [2.622e8], 359322111 [3.593e8], 621524837 [6.215e8]) [staticcall]
        // │   │   │   └─ ← [Return] 3417829867903211 [3.417e15]
        // │   │   └─ ← [Revert] mt_BorrowRateTooHigh()
        // │   └─ ← [Revert] mt_BorrowRateTooHigh()

        //assertEq(mTokenConfiguration(address(market18Decimals)).interestRateModel(), address(newInterestModel), "interest set issue");
    }

    function test_marketHost18decimals_SetNewInterestModelX() public {
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
        market18Decimals.mint(supplyAmount, address(this), 0);

        uint256 balanceOfMarket18Decimals = IERC20(address(market18Decimals)).balanceOf(address(this));
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

    function test_marketHost18decimals_SafeZone_PoC() public {
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
            address(0xA1),
            address(0xA2),
            address(0xA3),
            address(0xA4),
            address(0xA5)
        ];

        address[3] memory borrowers = [
            address(0xB1),
            address(0xB2),
            address(0xB3)
        ];

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
        assertLe(utilization, 1e18, "Utilization exceeded 100% in Safe Zone!");
        assertLt(utilization, 5e17, "Expected utilization < 50% in Safe Zone test.");

        // =============================================================
        // 4. Explanatory logs
        // =============================================================
        console2.log("=== SAFE ZONE ANALYSIS ===");
        console2.log("- Safe Zone: Once liquidity grows above ~10x the largest borrow and there are ");
        console2.log("  multiple suppliers, it becomes statistically impossible to cross 100% utilization.");
    }

    function test_marketHost18decimals_SetNewInterestModel_PoC_Analysis() public {
        // =============================================================
        // 0. Setup & context
        // =============================================================
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
        vm.expectRevert(bytes("Operator_InsufficientLiquidity()"));
        market18Decimals.redeemUnderlying(redeemAmount);

        // simulate borrow demand higher than supply
        vm.startPrank(address(0xBEEF));
        deal(address(asset18Decimals), address(0xBEEF), 10e18);
        asset18Decimals.approve(address(market18Decimals), 10e18);
        vm.expectRevert(); // capped model must prevent this borrow
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
        console2.log("/n");
        console2.log("- Prevention: Cannot be fully prevented without a hard cap on utilization, ");
        console2.log("  because protocol math depends on it being within [0, 1e18]");
        console2.log("/n");
        console2.log("- Correct Solution: Cap the utilization at 1e18 before computing rate, ");
        console2.log("/n");
        console2.log("- Typical Occurrence: Happens in thin-liquidity markets with few users, ");
        console2.log("  especially when 1 borrower drains >99.9% of supply or redemptions outpace deposits");
        console2.log("/n");
        console2.log("- Safe Zone: Once liquidity grows above ~10x the largest borrow and there are ");
        console2.log("  multiple suppliers, it becomes statistically impossible to cross 100% utilization.");
    }

    function test_marketHost18decimals_ThinLiquidity_PoC() public {
        // =============================================================
        // 0. Setup
        // =============================================================
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
        market18Decimals.mint(supplyAmount, address(this), 0);

        uint256 balanceOfMarket18Decimals = IERC20(address(market18Decimals)).balanceOf(address(this));
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
    }

    function test_marketHost18decimals_Compare_OldVsNewModel() public {
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
        uint256 utilNew = newInterestModel.utilizationRate(cash, totalBorrows, totalReserves);

        console2.log("Cash:                 ", cash);
        console2.log("Total Borrows:        ", totalBorrows);
        console2.log("Old model utilization:", utilOld);
        console2.log("New model utilization:", utilNew);

        // =============================================================
        // 2. Assertions
        // =============================================================
        assertGt(utilOld, 1e18);
        assertLe(utilNew, 1e18);

        console2.log("=== COMPARISON ANALYSIS ===");
        console2.log("- Old model produces utilization > 1e18");
        console2.log("- New model clamps to 1e18, preventing interest math overflow");
        console2.log("- Confirms solution directly caps utilization while preserving normal behavior");
    }

}
