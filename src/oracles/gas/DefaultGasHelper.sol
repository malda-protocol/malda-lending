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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DefaultGasHelper
/// @author Merge Layers Inc.
/// @notice Helper contract for managing gas fees
contract DefaultGasHelper is Ownable {
    // ----------- STORAGE ------------
    /// @notice Mapping of chain IDs to gas fees
    mapping(uint32 chainId => uint256 fee) public gasFees;

    // ----------- EVENTS ------------
    /// @notice Event emitted when gas fee is updated
    /// @param dstChainId The destination chain ID
    /// @param amount The gas fee amount
    event GasFeeUpdated(uint32 indexed dstChainId, uint256 amount);

    /// @notice Constructor
    /// @param owner_ The owner address
    constructor(address owner_) Ownable(owner_) {}

    // ----------- OWNER ------------
    /// @notice Sets the gas fee
    /// @param dstChainId The destination chain id
    /// @param amount The gas fee amount
    function setGasFee(uint32 dstChainId, uint256 amount) external onlyOwner {
        // Effects: set the gas fee
        gasFees[dstChainId] = amount;

        // Events: emit the gas fee updated event
        emit GasFeeUpdated(dstChainId, amount);
    }
}
