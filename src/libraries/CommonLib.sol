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

import {IGasFeesHelper} from "src/interfaces/IGasFeesHelper.sol";

/// @title CommonLib
/// @author Merge Layers Inc.
/// @notice Shared helper utilities for validation and math
library CommonLib {
    // ----------- ERRORS ------------
    /// @notice Thrown when array lengths mismatch
    error CommonLib_LengthMismatch();

    /// @notice Thrown when amount is invalid
    error AmountNotValid();

    /// @notice Thrown when chain id is not allowed
    error ChainNotValid();

    /// @notice Thrown when provided gas fee is insufficient
    error NotEnoughGasFee();

    // ----------- FUNCTIONS ------------
    /// @notice Checks a host to extension call for validity
    /// @param amount Amount being transferred
    /// @param dstChainId Destination chain id
    /// @param msgValue Message value provided
    /// @param allowedChains Mapping of allowed chain ids
    /// @param gasHelper Gas helper contract
    function checkHostToExtension(
        uint256 amount,
        uint32 dstChainId,
        uint256 msgValue,
        mapping(uint32 => bool) storage allowedChains,
        IGasFeesHelper gasHelper
    ) internal view {
        // Requirements: amount cannot be zero
        require(amount != 0, AmountNotValid());

        // Requirements: destination chain id is allowed
        require(allowedChains[dstChainId], ChainNotValid());

        uint256 requiredGas = address(gasHelper) != address(0) ? gasHelper.gasFees(dstChainId) : 0;

        // Requirements: message value is sufficient
        require(msgValue >= requiredGas, NotEnoughGasFee());
    }

    /// @notice Ensures two lengths match
    /// @param l1 First length
    /// @param l2 Second length
    function checkLengthMatch(uint256 l1, uint256 l2) internal pure {
        // Requirements: lengths must match
        require(l1 == l2, CommonLib_LengthMismatch());
    }

    /// @notice Ensures three lengths match
    /// @param l1 First length
    /// @param l2 Second length
    /// @param l3 Third length
    function checkLengthMatch(uint256 l1, uint256 l2, uint256 l3) internal pure {
        // Requirements: lengths must match
        require(l1 == l2 && l2 == l3, CommonLib_LengthMismatch());
    }

    /// @notice Computes sum of an array
    /// @param values Array of values
    /// @return sum Total sum
    function computeSum(uint256[] calldata values) internal pure returns (uint256 sum) {
        uint256 length = values.length;
        for (uint256 i; i < length; i++) {
            sum += values[i];
        }
    }
}
