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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRoles} from "./interfaces/IRoles.sol";

/// @title Role registry
/// @author Malda Protocol
/// @notice Ownable registry for assigning protocol roles to contracts.
contract Roles is Ownable, IRoles {
    // ----------- CONSTANTS ------------
    /// @notice Rebalancer role
    bytes32 public constant REBALANCER = keccak256("REBALANCER");
    /// @notice Pause manager role
    bytes32 public constant PAUSE_MANAGER = keccak256("PAUSE_MANAGER");
    /// @notice Rebalancer EOA role
    bytes32 public constant REBALANCER_EOA = keccak256("REBALANCER_EOA");
    /// @notice Guardian pause role
    bytes32 public constant GUARDIAN_PAUSE = keccak256("GUARDIAN_PAUSE");
    /// @notice Chains manager role
    bytes32 public constant CHAINS_MANAGER = keccak256("CHAINS_MANAGER");
    /// @notice Proof forwarder role
    bytes32 public constant PROOF_FORWARDER = keccak256("PROOF_FORWARDER");
    /// @notice Proof batch forwarder role
    bytes32 public constant PROOF_BATCH_FORWARDER = keccak256("PROOF_BATCH_FORWARDER");
    /// @notice Sequencer role
    bytes32 public constant SEQUENCER = keccak256("SEQUENCER");
    /// @notice Bridge guardian role
    bytes32 public constant GUARDIAN_BRIDGE = keccak256("GUARDIAN_BRIDGE");
    /// @notice Oracle guardian role
    bytes32 public constant GUARDIAN_ORACLE = keccak256("GUARDIAN_ORACLE");
    /// @notice Reserve guardian role
    bytes32 public constant GUARDIAN_RESERVE = keccak256("GUARDIAN_RESERVE");
    /// @notice Borrow cap guardian role
    bytes32 public constant GUARDIAN_BORROW_CAP = keccak256("GUARDIAN_BORROW_CAP");
    /// @notice Supply cap guardian role
    bytes32 public constant GUARDIAN_SUPPLY_CAP = keccak256("GUARDIAN_SUPPLY_CAP");
    /// @notice Blacklist guardian role
    bytes32 public constant GUARDIAN_BLACKLIST = keccak256("GUARDIAN_BLACKLIST");

    // ----------- STORAGE ------------
    /// @notice Role assignment mapping: contract => role => allowed
    mapping(address contractAddress => mapping(bytes32 roleIdentifier => bool allowed)) private _roles;

    /**
     * @notice Emitted when role allowance is updated
     * @param _contract The contract being updated
     * @param _role The role identifier
     * @param _allowed New allowance status
     */
    event Allowed(address indexed _contract, bytes32 indexed _role, bool _allowed);

    /// @notice Initializes the role registry
    /// @param owner_ Owner address
    constructor(address owner_) Ownable(owner_) {}

    // ----------- OWNER ------------
    /**
     * @notice Abiltity to allow a contract for a role or not
     * @param _contract the contract's address.
     * @param _role the bytes32 role.
     * @param _allowed the new status.
     */
    function allowFor(address _contract, bytes32 _role, bool _allowed) external onlyOwner {
        require(_contract != address(0) && _role != bytes32(0), Roles_InputNotValid());
        _roles[_contract][_role] = _allowed;
        emit Allowed(_contract, _role, _allowed);
    }

    // ----------- VIEW ------------
    /**
     * @notice Checks if a contract has a given role
     * @param _contract Contract address
     * @param _role Role identifier
     * @return True if allowed
     */
    function isAllowedFor(address _contract, bytes32 _role) external view override returns (bool) {
        return _roles[_contract][_role];
    }
}
