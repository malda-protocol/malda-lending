// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
// contracts
import {Operator} from "src/Operator/Operator.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";
import {OracleMockPerToken} from "test/mocks/OracleMockPerToken.sol";

import {console} from "forge-std/console.sol";

contract LiquidationTest is BaseMTokenTest {
    address internal borrower;
    address internal liquidator;

    function setUp() public virtual override {
        super.setUp();
        borrower = users.alice;
        liquidator = users.bob;

        operator.supportMarket(address(mWeth));
        operator.supportMarket(address(mDaiHost));

        oracleOperator.setUnderlyingPrice(DEFAULT_ORACLE_PRICE);

        // borrower needs WETH to supply
        _getTokens(weth, borrower, 1000 ether);
        vm.startPrank(borrower);
        weth.approve(address(mWeth), type(uint256).max);
        mWeth.mint(1000 ether, borrower, 1000 ether - 1e12);
        vm.stopPrank();

        // enter markets so collateral counts
        address[] memory markets = new address[](1);
        markets[0] = address(mWeth);
        operator.enterMarkets(markets);
        operator.setCollateralFactor(address(mWeth), DEFAULT_COLLATERAL_FACTOR);
        operator.setCloseFactor(9e17); //90%
        operator.setLiquidationIncentive(address(mWeth), 1e17);
        operator.setLiquidationIncentive(address(mDaiHost), 1e17);
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success_simulation_WhenCollateralFactorDropped() public {
        _getTokens(weth, borrower, 1000 ether);
        vm.startPrank(borrower);
        weth.approve(address(mWeth), type(uint256).max);
        mWeth.mint(1000 ether, borrower, 1000 ether - 1000);
        vm.stopPrank();

        _getTokens(weth, borrower, 1000 ether);
        vm.startPrank(borrower);
        weth.approve(address(mWeth), type(uint256).max);
        mWeth.mint(1000 ether, borrower, 1000 ether - 1000);
        vm.stopPrank();

        _getTokens(dai, address(this), 5000 ether);
        dai.approve(address(mDaiHost), type(uint256).max);
        mDaiHost.mint(5000 ether, address(this), 5000 ether - 1000);

        vm.prank(borrower);
        mDaiHost.borrow(1000 ether);

        _getTokens(dai, liquidator, 2000 ether);
        vm.prank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);

        // force undercollateralization; reduce collateral factor to 10%
        operator.setCollateralFactor(address(mWeth), 0.1e18);

        uint256 borrowerCollatBefore = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatBefore = mWeth.balanceOf(liquidator);

        // perform liquidation
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, 500 ether, address(mWeth));

        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    function test_unit_balanceOf_success_simulation_PriceDropHalf() public {
        OracleMockPerToken newOracle = new OracleMockPerToken(address(this));
        operator.setPriceOracle(address(newOracle));
        newOracle.setUnderlyingPrice(address(mWeth), 1e18);
        newOracle.setUnderlyingPrice(address(mDaiHost), 1e18);

        _getTokens(weth, borrower, 1000 ether);
        vm.startPrank(borrower);
        weth.approve(address(mWeth), type(uint256).max);
        mWeth.mint(1000 ether, borrower, 1000 ether - 1000);
        vm.stopPrank();

        _getTokens(dai, address(this), 5000 ether);
        dai.approve(address(mDaiHost), type(uint256).max);
        mDaiHost.mint(5000 ether, address(this), 5000 ether - 1000);

        vm.prank(borrower);
        mDaiHost.borrow(1000 ether);

        _getTokens(dai, liquidator, 2000 ether);
        vm.prank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);

        // price drop
        newOracle.setUnderlyingPrice(address(mWeth), 5e17); // $0.50

        uint256 borrowerCollatBefore = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatBefore = mWeth.balanceOf(liquidator);

        // perform liquidation
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, 500 ether, address(mWeth));

        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    function test_unit_balanceOf_success_simulation_PriceDropHalf_AndLog() public {
        OracleMockPerToken newOracle = new OracleMockPerToken(address(this));
        operator.setPriceOracle(address(newOracle));
        newOracle.setUnderlyingPrice(address(mWeth), 1e18);
        newOracle.setUnderlyingPrice(address(mDaiHost), 1e18);

        _getTokens(weth, borrower, 1000 ether);
        vm.startPrank(borrower);
        weth.approve(address(mWeth), type(uint256).max);
        mWeth.mint(1000 ether, borrower, 1000 ether - 1000);
        vm.stopPrank();

        _getTokens(dai, address(this), 5000 ether);
        dai.approve(address(mDaiHost), type(uint256).max);
        mDaiHost.mint(5000 ether, address(this), 5000 ether - 1000);

        vm.prank(borrower);
        mDaiHost.borrow(1000 ether);

        _getTokens(dai, liquidator, 2000 ether);
        vm.prank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);

        uint256 collatTokens = mWeth.balanceOf(borrower);
        uint256 collatPrice = newOracle.getUnderlyingPrice(address(mWeth));
        uint256 collatValue = (collatTokens * collatPrice) / 1e18;

        uint256 borrowBalance = mDaiHost.borrowBalanceStored(borrower);
        uint256 daiPrice = newOracle.getUnderlyingPrice(address(mDaiHost));
        uint256 borrowValue = (borrowBalance * daiPrice) / 1e18;

        console.log("--- BEFORE price drop ---");
        console.log("Collateral balance   :", collatTokens);
        console.log("Collateral price     :", collatPrice);
        console.log("Collateral value (USD):", collatValue);
        console.log("Borrow balance       :", borrowBalance);
        console.log("Borrow value (USD)   :", borrowValue);

        // price drop
        newOracle.setUnderlyingPrice(address(mWeth), 5e17);

        collatPrice = newOracle.getUnderlyingPrice(address(mWeth));
        collatValue = (collatTokens * collatPrice) / 1e18;
        borrowValue = (borrowBalance * daiPrice) / 1e18;

        console.log("--- AFTER price drop ---");
        console.log("Collateral price     :", collatPrice);
        console.log("Collateral value (USD):", collatValue);
        console.log("Borrow value (USD)   :", borrowValue);

        uint256 borrowerCollatBefore = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatBefore = mWeth.balanceOf(liquidator);

        // perform liquidation
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, 500 ether, address(mWeth));

        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        uint256 seized = liquidatorCollatAfter - liquidatorCollatBefore;

        console.log("--- AFTER liquidation ---");
        console.log("Borrower collateral before:", borrowerCollatBefore);
        console.log("Borrower collateral after :", borrowerCollatAfter);
        console.log("Seized collateral         :", seized);
        console.log("Liquidator collateral after:", liquidatorCollatAfter);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    ////////////////////////////////////////////////////////////
    //                   SetUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setUnderlyingPrice_success_simulation_PriceDropNormal_AndLog() public {
        OracleMockPerToken newOracle = new OracleMockPerToken(address(this));
        operator.setPriceOracle(address(newOracle));
        newOracle.setUnderlyingPrice(address(mWeth), 1e18);
        newOracle.setUnderlyingPrice(address(mDaiHost), 1e18);

        _getTokens(weth, borrower, 1000 ether);
        vm.startPrank(borrower);
        weth.approve(address(mWeth), type(uint256).max);
        mWeth.mint(1000 ether, borrower, 1000 ether - 1000);
        vm.stopPrank();

        _getTokens(dai, address(this), 5000 ether);
        dai.approve(address(mDaiHost), type(uint256).max);
        mDaiHost.mint(5000 ether, address(this), 5000 ether - 1000);

        vm.prank(borrower);
        mDaiHost.borrow(1000 ether);

        _getTokens(dai, liquidator, 2000 ether);
        vm.prank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);

        // uint256 borrowBalance = mDaiHost.borrowBalanceStored(borrower); // unused
        // uint256 daiPrice = newOracle.getUnderlyingPrice(address(mDaiHost)); // unused

        (, uint256 collatFactor) = Operator(operator).markets(address(mWeth));

        // drop in steps; 5% basically for each
        console.log("--- Drop starts ---");
        uint256 price = 1e18;
        while (true) {
            uint256 collatBal = mWeth.balanceOf(borrower);
            uint256 collatPrice = newOracle.getUnderlyingPrice(address(mWeth));
            uint256 borrowBal = mDaiHost.borrowBalanceStored(borrower);

            uint256 collatValue = (collatBal * collatPrice) / 1e18;
            uint256 borrowValue = borrowBal; // DAI is $1

            // health factor scaled by 1e18
            uint256 healthFactor = (collatValue * collatFactor) / borrowValue;
            uint256 healthFactorNormalized = (collatValue * collatFactor) / borrowValue;

            console.log("---> step <---");
            console.log("  Collateral price       :", collatPrice);
            console.log("  Collateral value (USD) :", collatValue);
            console.log("  Borrow value (USD)     :", borrowValue);
            console.log("  Health factor          :", healthFactor, "/", collatFactor);
            console.log("  Health factor (scaled 1e18):", healthFactorNormalized);
            // HF >= 1e18 → healthy
            // HF < 1e18 → liquidatable

            vm.startPrank(liquidator);
            try mDaiHost.liquidate(borrower, 100 ether, address(mWeth)) {
                console.log(">>> Liquidation succeeded at price:", price);
                break;
            } catch {
                // drop price 5%
                price = (price * 95) / 100;
                vm.stopPrank();
                newOracle.setUnderlyingPrice(address(mWeth), price);

                // avoid infinite loop
                if (price < 1e16) {
                    revert("something wrong");
                }
            }
        }
    }
}
