// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {OracleMockPerToken} from "test/mocks/OracleMockPerToken.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";

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

    function test_fuzz_balanceOf_success_simulation_WhenCollateralFactorDropped(uint256 repayAmount) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        repayAmount = bound(repayAmount, 1 ether, 900 ether);

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

        vm.startPrank(borrower);
        mDaiHost.borrow(1000 ether);
        vm.stopPrank();

        _getTokens(dai, liquidator, 2000 ether);
        vm.startPrank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);
        vm.stopPrank();

        // force undercollateralization; reduce collateral factor to 10%
        operator.setCollateralFactor(address(mWeth), 0.1e18);

        uint256 borrowerCollatBefore = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatBefore = mWeth.balanceOf(liquidator);

        // perform liquidation

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));

        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    function test_fuzz_balanceOf_success_simulation_PriceDropHalf(uint256 repayAmount) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        repayAmount = bound(repayAmount, 1 ether, 900 ether);

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

        vm.startPrank(borrower);
        mDaiHost.borrow(1000 ether);
        vm.stopPrank();

        _getTokens(dai, liquidator, 2000 ether);
        vm.startPrank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);
        vm.stopPrank();

        // price drop
        newOracle.setUnderlyingPrice(address(mWeth), 5e17); // $0.50

        uint256 borrowerCollatBefore = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatBefore = mWeth.balanceOf(liquidator);

        // perform liquidation

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));

        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    function test_fuzz_balanceOf_success_simulation_PriceDropHalf_AndLog(uint256 repayAmount) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        repayAmount = bound(repayAmount, 1 ether, 900 ether);

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

        vm.startPrank(borrower);
        mDaiHost.borrow(1000 ether);
        vm.stopPrank();

        _getTokens(dai, liquidator, 2000 ether);
        vm.startPrank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);
        vm.stopPrank();

        // price drop
        newOracle.setUnderlyingPrice(address(mWeth), 5e17);

        uint256 borrowerCollatBefore = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatBefore = mWeth.balanceOf(liquidator);

        // perform liquidation

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    ////////////////////////////////////////////////////////////
    //                   SetUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setUnderlyingPrice_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
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

        vm.startPrank(borrower);
        mDaiHost.borrow(1000 ether);
        vm.stopPrank();

        _getTokens(dai, liquidator, 2000 ether);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        dai.approve(address(mDaiHost), type(uint256).max);

        // uint256 borrowBalance = mDaiHost.borrowBalanceStored(borrower); // unused
        // uint256 daiPrice = newOracle.getUnderlyingPrice(address(mDaiHost)); // unused

        // drop in steps; 5% basically for each
        uint256 price = 1e18;
        while (true) {
            vm.startPrank(liquidator);
            try mDaiHost.liquidate(borrower, 100 ether, address(mWeth)) {
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
