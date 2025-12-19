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

import {ImTokenOperationTypes} from "./ImToken.sol";

/// @title IPauser
/// @author Merge Layers Inc.
/// @notice Interface for pausing market operations
interface IPauser is ImTokenOperationTypes {
    enum PausableType {
        NonPausable,
        Host,
        Extension
    }

    struct PausableContract {
        address market;
        PausableType contractType;
    }

    // ----------- EVENTS ------------
    /// @notice Emitted when all markets are paused
    event PauseAll();

    /// @notice Emitted when a market is paused
    /// @param market The paused market
    event MarketPaused(address indexed market);

    /// @notice Emitted when a market is removed
    /// @param market The market removed
    event MarketRemoved(address indexed market);

    /// @notice Emitted when a market is added
    /// @param market The market added
    /// @param marketType The market type
    event MarketAdded(address indexed market, PausableType marketType);

    /// @notice Emitted when a specific operation is paused for a market
    /// @param market The market paused
    /// @param pauseType The operation type paused
    event MarketPausedFor(address indexed market, OperationType pauseType);

    // ----------- ERRORS ------------
    /// @notice Error when entry is not found
    error Pauser_EntryNotFound();

    /// @notice Error when caller lacks authorization
    error Pauser_NotAuthorized();

    /// @notice Error when provided address is invalid
    error Pauser_AddressNotValid();

    /// @notice Error when market already registered
    error Pauser_AlreadyRegistered();

    /// @notice Error when contract is not enabled
    error Pauser_ContractNotEnabled();

    // ----------- EXTERNAL ------------
    /// @notice Pauses all operations for a market
    /// @param _market the mToken address
    function emergencyPauseMarket(address _market) external;

    /// @notice Pauses a specific operation for a market
    /// @param _market the mToken address
    /// @param _pauseType the operation type
    function emergencyPauseMarketFor(address _market, OperationType _pauseType) external;

    /// @notice Pauses all operations for all registered markets
    function emergencyPauseAll() external;
}
