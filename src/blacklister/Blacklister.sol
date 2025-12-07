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

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IRoles} from "src/interfaces/IRoles.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";

/// @title Blacklister
/// @author Merge Layers Inc.
/// @notice Contract for managing blacklisted addresses
contract Blacklister is OwnableUpgradeable, IBlacklister {
    // ----------- STORAGE -----------
    /// @notice Mapping of addresses to their blacklist status
    mapping(address user => bool isBlacklisted) public isBlacklisted;

    address[] private _blacklistedList;

    /// @notice The roles operator contract
    IRoles public rolesOperator;

    // ----------- ERRORS -----------
    /// @notice Error thrown when address is already blacklisted
    error Blacklister_AlreadyBlacklisted();
    /// @notice Error thrown when address is not blacklisted
    error Blacklister_NotBlacklisted();
    /// @notice Error thrown when caller is not authorized
    error Blacklister_NotAllowed();

    /// @notice Modifier to restrict access to owner or guardian
    modifier onlyOwnerOrGuardian() {
        require(
            msg.sender == owner() || rolesOperator.isAllowedFor(msg.sender, rolesOperator.GUARDIAN_BLACKLIST()),
            Blacklister_NotAllowed()
        );
        _;
    }

    /// @notice Disables initializers on implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _owner The owner address
    /// @param _roles The roles contract address
    function initialize(address payable _owner, address _roles) external initializer {
        __Ownable_init(_owner);
        rolesOperator = IRoles(_roles);
    }

    // ----------- OWNER ------------
    /// @notice Blacklist an address
    /// @param user The address to blacklist
    function blacklist(address user) external override onlyOwnerOrGuardian {
        // @audit use custom error
        if (isBlacklisted[user]) revert Blacklister_AlreadyBlacklisted();
        _addToBlacklist(user);
    }

    /// @notice Remove an address from blacklist
    /// @param user The address to unblacklist
    function unblacklist(address user) external override onlyOwnerOrGuardian {
        if (!isBlacklisted[user]) revert Blacklister_NotBlacklisted();
        isBlacklisted[user] = false;
        _removeFromBlacklistList(user);
        emit Unblacklisted(user);
    }

    /// @notice Remove an address from blacklist by index
    /// @param user The address to unblacklist
    /// @param index The index in the blacklist array
    function unblacklist(address user, uint256 index) external override onlyOwnerOrGuardian {
        if (!isBlacklisted[user]) revert Blacklister_NotBlacklisted();
        isBlacklisted[user] = false;
        _removeFromBlacklistList(user, index);
        emit Unblacklisted(user);
    }

    // ----------- VIEW ------------
    /// @notice Get all blacklisted addresses
    /// @return Array of blacklisted addresses
    function getBlacklistedAddresses() external view returns (address[] memory) {
        return _blacklistedList;
    }

    // ----------- INTERNAL ------------
    /// @notice Internal function to add an address to blacklist
    /// @param user The address to blacklist
    function _addToBlacklist(address user) internal {
        isBlacklisted[user] = true;
        _blacklistedList.push(user);
        emit Blacklisted(user);
    }

    /// @notice Internal function to remove an address from blacklist list
    /// @param user The address to remove
    function _removeFromBlacklistList(address user) internal {
        uint256 len = _blacklistedList.length;
        for (uint256 i; i < len; ++i) {
            if (_blacklistedList[i] == user) {
                _blacklistedList[i] = _blacklistedList[len - 1];
                _blacklistedList.pop();
                break;
            }
        }
    }

    /// @notice Internal function to remove an address from blacklist list by index
    /// @param user The address to remove
    /// @param index The index in the blacklist array
    function _removeFromBlacklistList(address user, uint256 index) internal {
        uint256 len = _blacklistedList.length;
        if (_blacklistedList[index] == user) {
            _blacklistedList[index] = _blacklistedList[len - 1];
            _blacklistedList.pop();
        } else {
            revert Blacklister_NotBlacklisted();
        }
    }
}
