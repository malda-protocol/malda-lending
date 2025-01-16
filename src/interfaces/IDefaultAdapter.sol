// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IDefaultAdapter {
    struct PriceConfig {
        address defaultFeed; // chainlink & eOracle
        string toSymbol;
        uint256 underlyingDecimals;
    }

    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
        
    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);
}