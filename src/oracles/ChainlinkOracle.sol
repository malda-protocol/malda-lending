// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.

// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IOracleOperator} from "src/interfaces/IOracleOperator.sol";
import {IAggregatorV3} from "src/interfaces/external/chainlink/IAggregatorV3.sol";

/// @title ChainlinkOracle
/// @author Merge Layers Inc.
/// @notice Oracle contract using Chainlink price feeds
contract ChainlinkOracle is IOracleOperator {
    // ----------- CONSTANTS ------------

    /// @notice Number of decimals for price
    uint8 public constant DECIMALS = 18;

    // ----------- STORAGE ------------

    /// @notice Mapping of symbols to price feeds
    mapping(string symbol => IAggregatorV3 feed) public priceFeeds;

    /// @notice Mapping of symbols to base units
    mapping(string symbol => uint256 units) public baseUnits;

    // ----------- ERRORS ------------

    /// @notice Error thrown when no price feed is found
    error ChainlinkOracle_NoPriceFeed();
    /// @notice Error thrown when price is zero
    error ChainlinkOracle_ZeroPrice();

    /// @notice Constructor
    /// @param symbols_ Array of symbols
    /// @param feeds_ Array of price feeds
    /// @param baseUnits_ Array of base units
    constructor(string[] memory symbols_, IAggregatorV3[] memory feeds_, uint256[] memory baseUnits_) {
        for (uint256 i = 0; i < symbols_.length; i++) {
            priceFeeds[symbols_[i]] = feeds_[i];
            baseUnits[symbols_[i]] = baseUnits_[i];
        }
    }

    // ----------- PUBLIC ------------
    /// @inheritdoc IOracleOperator
    function getPrice(address mToken) external view override returns (uint256) {
        string memory symbol = ImTokenMinimal(mToken).symbol();
        uint256 feedDecimals = priceFeeds[symbol].decimals();

        (uint256 price,) = _getLatestPrice(symbol);

        return price * 10 ** (18 - feedDecimals);
    }

    /// @inheritdoc IOracleOperator
    function getUnderlyingPrice(address mToken) external view override returns (uint256) {
        string memory symbol = ImTokenMinimal(ImTokenMinimal(mToken).underlying()).symbol();
        uint256 feedDecimals = priceFeeds[symbol].decimals();

        (uint256 price,) = _getLatestPrice(symbol);
        return (price * (10 ** (36 - feedDecimals))) / baseUnits[symbol];
    }

    // ----------- PRIVATE ------------
    /// @notice Get the latest price for a symbol
    /// @param symbol The symbol to get price for
    /// @return price The price
    /// @return timeStamp The timestamp
    function _getLatestPrice(string memory symbol) internal view returns (uint256, uint256) {
        require(address(priceFeeds[symbol]) != address(0), ChainlinkOracle_NoPriceFeed());

        (,
            //uint80 roundID
            int256 price, //uint256 startedAt
            ,
            uint256 timeStamp, //uint80 answeredInRound
        ) = priceFeeds[symbol].latestRoundData();

        require(price > 0, ChainlinkOracle_ZeroPrice());
        uint256 uPrice = uint256(price);

        return (uPrice, timeStamp);
    }
}
