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

//  _____ _____ __    ____  _____
// |     |  _  |  |  |    \|  _  |
// | | | |     |  |__|  |  |     |
// |_|_|_|__|__|_____|____/|__|__|

/// @title IBlacklister
/// @author Merge Layers Inc.
/// @notice Interface for blacklisting addresses
interface IBlacklister {
    // ----------- EVENTS -----------
    /// @notice Emitted when a user is blacklisted
    /// @param user The blacklisted address
    event Blacklisted(address indexed user);
    /// @notice Emitted when a user is removed from blacklist
    /// @param user The unblacklisted address
    event Unblacklisted(address indexed user);

    // ----------- OWNER ACTIONS -----------
    /// @notice Blacklists a user immediately (onlyOwner).
    /// @param user The address to blacklist
    function blacklist(address user) external;

    /// @notice Removes a user from the blacklist (onlyOwner).
    /// @param user The address to unblacklist
    function unblacklist(address user) external;

    /// @notice Removes a user from the blacklist (onlyOwner).
    /// @param user The address to unblacklist
    /// @param index The index of the user in blacklist array
    function unblacklist(address user, uint256 index) external;

    // ----------- VIEW FUNCTIONS -----------
    /// @notice Returns the list of currently blacklisted addresses.
    /// @return blacklistedAddresses Array of blacklisted addresses
    function getBlacklistedAddresses() external view returns (address[] memory);

    /// @notice Returns whether a user is currently blacklisted.
    /// @param user The address to check
    /// @return isUserBlacklisted True if the user is blacklisted
    function isBlacklisted(address user) external view returns (bool);
}
