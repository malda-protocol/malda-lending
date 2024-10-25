// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

/**
 * @notice Prices are returned in USD
 */
interface IOracleOperator {
    /**
     * @notice Get the price of a mToken asset
     * @param mToken The mToken to get the price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getPrice(address mToken) external view returns (uint256);

    /**
     * @notice Get the underlying price of a mToken asset
     * @param mToken The mToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getUnderlyingPrice(address mToken) external view returns (uint256);
}
