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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

// contracts
import {CREATE3} from "src/libraries/CREATE3.sol";

/// @title CREATE3-based deployer with admin control
/// @author Malda Protocol
/// @notice Minimal helper to precompute and deploy contracts via CREATE3 with two-step admin handover.
contract Deployer {
    /// @notice Current admin authorized to deploy and manage ownership
    address public admin;
    /// @notice Pending admin address that can accept control
    address public pendingAdmin;

    // ----------- EVENTS ------------
    /// @notice Emitted when admin is updated
    /// @param _admin New admin address
    event AdminSet(address indexed _admin);
    /// @notice Emitted when pending admin is set
    /// @param _admin Pending admin address
    event PendingAdminSet(address indexed _admin);
    /// @notice Emitted when pending admin accepts control
    /// @param _admin The admin address that just accepted
    event AdminAccepted(address indexed _admin);

    // ----------- ERRORS ------------
    error NotAuthorized(address admin, address sender);

    modifier onlyAdmin() {
        require(msg.sender == admin, NotAuthorized(admin, msg.sender));
        _;
    }

    /// @notice Initializes the deployer
    /// @param _admin Address that will control deployments
    constructor(address _admin) {
        require(_admin != address(0), NotAuthorized(address(0), msg.sender));
        admin = _admin;
    }

    /// @notice Accepts plain ETH transfers
    receive() external payable {}

    // ----------- OWNER ------------
    /**
     * @notice Propose a new admin that must later accept
     * @param newAdmin Address proposed as the next admin
     */
    function setPendingAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), NotAuthorized(address(0), msg.sender));
        pendingAdmin = newAdmin;

        emit PendingAdminSet(newAdmin);
    }

    /// @notice Withdraws all ETH to the admin
    function saveEth() external {
        if (admin == msg.sender) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success, "ETH");
        }
    }

    /**
     * @notice Directly sets a new admin (without pending/accept)
     * @param _addr New admin address
     */
    function setNewAdmin(address _addr) external {
        if (admin == msg.sender) {
            require(_addr != address(0), NotAuthorized(address(0), msg.sender));
            admin = _addr;

            emit AdminSet(_addr);
        }
    }

    // ----------- PUBLIC ------------
    /**
     * @notice Deploys a contract using CREATE3
     * @param salt Deterministic salt used for CREATE3
     * @param code Creation bytecode to deploy
     * @return deployed The deployed contract address
     */
    function create(bytes32 salt, bytes calldata code) external payable onlyAdmin returns (address deployed) {
        return CREATE3.deploy(salt, code, msg.value);
    }

    /// @notice Allows the pending admin to accept control
    function acceptAdmin() external {
        if (msg.sender != pendingAdmin) {
            revert NotAuthorized(pendingAdmin, msg.sender);
        }
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit AdminAccepted(admin);
    }

    // ----------- VIEW ------------
    /**
     * @notice Precomputes the deployment address for a given salt
     * @param salt Deterministic salt used for CREATE3
     * @return The address that would be deployed
     */
    function precompute(bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }
}
