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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

import {IRoles} from "src/interfaces/IRoles.sol";

/// @title Base bridge contract
/// @author Malda Protocol
/// @notice Abstract base for cross-chain bridge implementations with role-based access control
abstract contract BaseBridge {
    // ----------- STORAGE ------------
    /// @notice Roles contract for access control
    IRoles public roles;

    // ----------- ERRORS ------------
    /// @notice Error thrown when caller is not authorized
    error BaseBridge_NotAuthorized();

    /// @notice Error thrown when amount mismatch
    error BaseBridge_AmountMismatch();

    /// @notice Error thrown when amount is not valid
    error BaseBridge_AmountNotValid();

    /// @notice Error thrown when address is not valid
    error BaseBridge_AddressNotValid();

    // ----------- MODIFIERS ------------
    /// @notice Modifier to check if the caller is the bridge configurator
    modifier onlyBridgeConfigurator() {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), BaseBridge_NotAuthorized());
        _;
    }

    /// @notice Modifier to check if the caller is the rebalancer
    modifier onlyRebalancer() {
        // Requirements: the caller is the rebalancer
        require(roles.isAllowedFor(msg.sender, roles.REBALANCER()), BaseBridge_NotAuthorized());
        _;
    }

    /// @notice Initializes the base bridge
    /// @param _roles Roles contract address
    constructor(address _roles) {
        // Requirements: the roles address is not zero
        require(_roles != address(0), BaseBridge_AddressNotValid());

        // Effects: set the roles contract
        roles = IRoles(_roles);
    }
}
