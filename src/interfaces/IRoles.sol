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

/// @title IRoles
/// @author Merge Layers Inc.
/// @notice Interface for protocol role management
interface IRoles {
    // ----------- ERRORS ------------
    /// @notice Error thrown when input is not valid
    error Roles_InputNotValid();

    // ----------- VIEW ------------
    /// @notice Returns REBALANCER role
    /// @return role REBALANCER role identifier
    function REBALANCER() external view returns (bytes32 role);

    /// @notice Returns REBALANCER_EOA role
    /// @return role REBALANCER_EOA role identifier
    function REBALANCER_EOA() external view returns (bytes32 role);

    /// @notice Returns GUARDIAN_PAUSE role
    /// @return role GUARDIAN_PAUSE role identifier
    function GUARDIAN_PAUSE() external view returns (bytes32 role);

    /// @notice Returns GUARDIAN_BRIDGE role
    /// @return role GUARDIAN_BRIDGE role identifier
    function GUARDIAN_BRIDGE() external view returns (bytes32 role);

    /// @notice Returns GUARDIAN_BORROW_CAP role
    /// @return role GUARDIAN_BORROW_CAP role identifier
    function GUARDIAN_BORROW_CAP() external view returns (bytes32 role);

    /// @notice Returns GUARDIAN_SUPPLY_CAP role
    /// @return role GUARDIAN_SUPPLY_CAP role identifier
    function GUARDIAN_SUPPLY_CAP() external view returns (bytes32 role);

    /// @notice Returns GUARDIAN_RESERVE role
    /// @return role GUARDIAN_RESERVE role identifier
    function GUARDIAN_RESERVE() external view returns (bytes32 role);

    /// @notice Returns PROOF_FORWARDER role
    /// @return role PROOF_FORWARDER role identifier
    function PROOF_FORWARDER() external view returns (bytes32 role);

    /// @notice Returns PROOF_BATCH_FORWARDER role
    /// @return role PROOF_BATCH_FORWARDER role identifier
    function PROOF_BATCH_FORWARDER() external view returns (bytes32 role);

    /// @notice Returns SEQUENCER role
    /// @return role SEQUENCER role identifier
    function SEQUENCER() external view returns (bytes32 role);

    /// @notice Returns PAUSE_MANAGER role
    /// @return role PAUSE_MANAGER role identifier
    function PAUSE_MANAGER() external view returns (bytes32 role);

    /// @notice Returns CHAINS_MANAGER role
    /// @return role CHAINS_MANAGER role identifier
    function CHAINS_MANAGER() external view returns (bytes32 role);

    /// @notice Returns GUARDIAN_ORACLE role
    /// @return role GUARDIAN_ORACLE role identifier
    function GUARDIAN_ORACLE() external view returns (bytes32 role);

    /// @notice Returns GUARDIAN_BLACKLIST role
    /// @return role GUARDIAN_BLACKLIST role identifier
    function GUARDIAN_BLACKLIST() external view returns (bytes32 role);

    /// @notice Returns allowance status for a contract and a role
    /// @param _contract The contract address
    /// @param _role The bytes32 role
    /// @return isAllowed True if allowed
    function isAllowedFor(address _contract, bytes32 _role) external view returns (bool isAllowed);
}
