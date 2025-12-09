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

    /// @notice List of blacklisted addresses
    address[] private _blacklistedList;

    /// @notice The roles operator contract
    IRoles public rolesOperator;

    /// @notice Modifier to restrict access to owner or guardian
    modifier onlyOwnerOrGuardian() {
        // Requirements: caller is owner or has guardian blacklist role
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

        // Require: roles contract is not zero address
        require(_roles != address(0), Blacklister_InvalidRoles());

        // Effects: set roles operator
        rolesOperator = IRoles(_roles);
    }

    // ----------- OWNER ------------
    /// @inheritdoc IBlacklister
    function blacklist(address user) external override onlyOwnerOrGuardian {
        // Requirements: address is not already blacklisted
        require(!isBlacklisted[user], Blacklister_AlreadyBlacklisted());

        // Effects: add address to blacklist
        _addToBlacklist(user);
    }

    /// @inheritdoc IBlacklister
    function unblacklist(address user) external override onlyOwnerOrGuardian {
        // Requirements: address is not blacklisted
        require(isBlacklisted[user], Blacklister_NotBlacklisted());

        // Effects: remove address from blacklist
        _removeFromBlacklist(user);

        // Events: emit unblacklisted event
        emit Unblacklisted(user);
    }

    /// @inheritdoc IBlacklister
    function unblacklist(address user, uint256 index) external override onlyOwnerOrGuardian {
        // Requirements: address is not blacklisted
        require(isBlacklisted[user], Blacklister_NotBlacklisted());

        // Effects: remove address from blacklist
        _removeFromBlacklist(user, index);

        // Events: emit unblacklisted event
        emit Unblacklisted(user);
    }

    // ----------- VIEW ------------
    /// @inheritdoc IBlacklister
    function getBlacklistedAddresses() external view returns (address[] memory) {
        return _blacklistedList;
    }

    // ----------- INTERNAL ------------
    /// @notice Internal function to add an address to blacklist
    /// @param user The address to blacklist
    function _addToBlacklist(address user) internal {
        // Effects: set address to blacklisted
        isBlacklisted[user] = true;

        // Effects: add address to blacklist list
        _blacklistedList.push(user);

        // Events: emit blacklisted event
        emit Blacklisted(user);
    }

    /// @notice Internal function to remove an address from blacklist list
    /// @param user The address to remove
    function _removeFromBlacklist(address user) internal {
        // Effects: set address to not blacklisted
        isBlacklisted[user] = false;

        uint256 len = _blacklistedList.length;
        for (uint256 i; i < len; ++i) {
            if (_blacklistedList[i] == user) {
                // Effects: remove address from blacklist list
                _blacklistedList[i] = _blacklistedList[len - 1];
                _blacklistedList.pop();
                break;
            }
        }
    }

    /// @notice Internal function to remove an address from blacklist list by index
    /// @param user The address to remove
    /// @param index The index in the blacklist array
    function _removeFromBlacklist(address user, uint256 index) internal {
        // Effects: set address to not blacklisted
        isBlacklisted[user] = false;

        uint256 len = _blacklistedList.length;
        if (_blacklistedList[index] == user) {
            // Effects: remove address from blacklist list
            _blacklistedList[index] = _blacklistedList[len - 1];
            _blacklistedList.pop();
        } else {
            revert Blacklister_NotBlacklisted();
        }
    }
}
