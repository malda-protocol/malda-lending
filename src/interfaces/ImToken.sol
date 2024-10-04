// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                          
*/

interface ImTokenMinimal {
    /**
     * @notice Returns the value of tokens owned by `account`.
     * @param account The account to check for
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);
}

interface ImToken is ImTokenMinimal {
    /**
     * @notice Total amount of outstanding borrows of the underlying in this market
     */
    function totalBorrows() external view returns (uint256);

    /**
     * @notice Accumulator of the total earned interest rate since the opening of the market
     */
    function borrowIndex() external view returns (uint256);

    /**
     * @notice Returns Borrow balance for account
     * @param account The account to check for
     */
    function borrowBalanceStored(address account) external view returns (uint256);

    /**
     * @notice Moves a `value` amount of tokens from the caller's account to `dst`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     */
    function transfer(address dst, uint256 amount) external returns (bool);

    /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (possible error, token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Returns exchange rate
     */
    function exchangeRateStored() external view returns (uint256);
}
