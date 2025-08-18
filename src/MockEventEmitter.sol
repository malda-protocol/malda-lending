// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;


contract MockEventEmitter {
    event LiquidateBorrow(
        address indexed liquidator,
        address indexed borrower,
        uint256 repayAmount,
        address indexed mTokenCollateral,
        uint256 seizeTokens
    );


    function emitEvent(address liquidator, address borrower, uint256 repayAmount, address mTokenCollateral, uint256 seizeTokens) external {
        emit LiquidateBorrow(liquidator, borrower, repayAmount, mTokenCollateral, seizeTokens);
    }
}