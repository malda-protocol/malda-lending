// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {mTokenStorage} from "src/mToken/mTokenStorage.sol";

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
        operator.setCloseFactor(9e17); // 90%
        operator.setLiquidationIncentive(address(mWeth), 1e17);
        operator.setLiquidationIncentive(address(mDaiHost), 1e17);
    }

    ////////////////////////////////////////////////////////////
    //                       liquidate                        //
    ////////////////////////////////////////////////////////////

    function test_fuzz_liquidate_success_whenCollateralFactorDropped(uint256 repayAmount) public {
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
        vm.expectEmit(true, true, true, false);
        emit mTokenStorage.LiquidateBorrow(liquidator, borrower, repayAmount, address(mWeth), 0);
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));

        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    function test_fuzz_liquidate_success_whenCollateralPriceDropsByHalf(uint256 repayAmount) public {
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
        vm.expectEmit(true, true, true, false);
        emit mTokenStorage.LiquidateBorrow(liquidator, borrower, repayAmount, address(mWeth), 0);
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));

        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    function test_fuzz_liquidate_success_whenCollateralPriceDropsByHalfWithLogs(uint256 repayAmount) public {
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
        vm.expectEmit(true, true, true, false);
        emit mTokenStorage.LiquidateBorrow(liquidator, borrower, repayAmount, address(mWeth), 0);
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 borrowerCollatAfter = mWeth.balanceOf(borrower);
        uint256 liquidatorCollatAfter = mWeth.balanceOf(liquidator);

        assertLt(borrowerCollatAfter, borrowerCollatBefore, "should decrease");
        assertGt(liquidatorCollatAfter, liquidatorCollatBefore, "should seize collateral");
    }

    function test_unit_liquidate_revertsWith_mt_InvalidInput_whenRepayAmountZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 repayAmount = 0;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    function test_unit_liquidate_revertsWith_mt_InvalidInput_whenBorrowerEqualsLiquidator() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 repayAmount = 1 ether;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(borrower);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));
    }

    function test_fuzz_liquidate_success_emitsLiquidateBorrow(uint256 repayAmount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        repayAmount = bound(repayAmount, 1 ether, 100 ether);

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

        newOracle.setUnderlyingPrice(address(mWeth), 5e17);

        uint256 borrowerBorrowBefore = mDaiHost.borrowBalanceStored(borrower);
        uint256 borrowerCollateralBefore = mWeth.balanceOf(borrower);
        uint256 liquidatorCollateralBefore = mWeth.balanceOf(liquidator);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, false);
        emit mTokenStorage.LiquidateBorrow(liquidator, borrower, repayAmount, address(mWeth), 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(liquidator);
        mDaiHost.liquidate(borrower, repayAmount, address(mWeth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 borrowerBorrowAfter = mDaiHost.borrowBalanceStored(borrower);
        uint256 borrowerCollateralAfter = mWeth.balanceOf(borrower);
        uint256 liquidatorCollateralAfter = mWeth.balanceOf(liquidator);

        assertLt(
            borrowerBorrowAfter, borrowerBorrowBefore, "expected borrower borrow balance to decrease after liquidation"
        );
        assertLt(
            borrowerCollateralAfter,
            borrowerCollateralBefore,
            "expected borrower collateral balance to decrease after liquidation"
        );
        assertGt(
            liquidatorCollateralAfter,
            liquidatorCollateralBefore,
            "expected liquidator collateral balance to increase after liquidation"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  liquidate price walk                  //
    ////////////////////////////////////////////////////////////

    function test_unit_liquidate_success_whenCollateralPriceDropsInSteps() public {
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
            vm.prank(liquidator);
            try mDaiHost.liquidate(borrower, 100 ether, address(mWeth)) {
                break;
            } catch {
                // drop price 5%
                price = (price * 95) / 100;
                newOracle.setUnderlyingPrice(address(mWeth), price);

                // avoid infinite loop
                if (price < 1e16) {
                    revert("something wrong");
                }
            }
        }
    }
}
