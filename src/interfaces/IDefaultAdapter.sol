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
//
// This file contains code derived from or inspired by Compound V2,
// originally licensed under the BSD 3-Clause License. See LICENSE-COMPOUND-V2
// for original license terms and attributions.

// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

/// @title IDefaultAdapter
/// @author Merge Layers Inc.
/// @notice Default price adapter interface used for oracle feeds
interface IDefaultAdapter {
    struct PriceConfig {
        address defaultFeed; // chainlink & eOracle
        string toSymbol;
        uint256 underlyingDecimals;
    }

    /// @notice Returns the decimals for the price feed
    /// @return decimalsCount Number of decimals
    function decimals() external view returns (uint8);

    /// @notice Returns the latest round data from the feed
    /// @return roundId Round identifier
    /// @return answer Feed answer
    /// @return startedAt Round start timestamp
    /// @return updatedAt Round update timestamp
    /// @return answeredInRound The round in which the answer was computed
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    /// @notice Returns the latest answer
    /// @return answer Latest feed answer
    function latestAnswer() external view returns (int256);

    /// @notice Returns the latest timestamp
    /// @return timestamp Latest update timestamp
    function latestTimestamp() external view returns (uint256);
}
