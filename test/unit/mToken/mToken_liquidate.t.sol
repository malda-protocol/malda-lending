// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// interfaces
import {IOperatorDefender} from "src/interfaces/IOperator.sol";

// contracts
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";

// tests
import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mToken_liquidate is mToken_Unit_Shared {
    address internal borrower = address(0xB0B);
    address internal liquidator = address(0xBEEF);

    function test_Seize_RevertWhen_BorrowerIsLiquidator() external {
        operator.supportMarket(address(mWeth));
        operator.supportMarket(address(mDaiHost));

        vm.prank(address(mDaiHost));
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mWeth.seize(borrower, borrower, 1);
    }

    function test_Liquidate_RevertWhen_BorrowerIsLiquidator() external {
        vm.prank(liquidator);
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mDaiHost.liquidate(liquidator, 1 ether, address(mWeth));
    }

    function test_Liquidate_RevertWhen_RepayAmountIsZero() external {
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mDaiHost.liquidate(borrower, 0, address(mWeth));
    }

    function test_Liquidate_RevertWhen_RepayAmountIsMax() external {
        vm.expectRevert(mTokenStorage.mt_InvalidInput.selector);
        mDaiHost.liquidate(borrower, type(uint256).max, address(mWeth));
    }

    function test_Liquidate_RevertWhen_CollateralBlockTimestampNotValid() external {
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

    function test_Liquidate_RevertWhen_PriceFetchFailed() external {
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

    function test_Liquidate_RevertWhen_SeizeTooMuch() external {
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
