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

// contracts
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {IPauser} from "src/interfaces/IPauser.sol";
import {IOperator} from "src/interfaces/IOperator.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

/// @title Pauser
/// @author Merge Layers Inc.
/// @notice Manages pausing operations across deployed markets
contract Pauser is Ownable, IPauser {
    // ----------- IMMUTABLES ------------
    /// @notice Roles contract reference
    IRoles public immutable ROLES;

    /// @notice Operator contract reference
    IOperator public immutable OPERATOR;

    // ----------- STORAGE ------------
    /// @notice List of contracts that can be paused
    PausableContract[] public pausableContracts;

    /// @notice Tracks whether a contract is registered as pausable
    mapping(address _contract => bool _registered) public registeredContracts;

    /// @notice Contract type for each registered market
    mapping(address _contract => PausableType _type) public contractTypes;

    /// @notice Sets initial configuration for roles, operator, and owner
    /// @param _roles Address of the roles contract
    /// @param _operator Address of the operator contract
    /// @param owner_ Owner address of the pauser contract
    constructor(address _roles, address _operator, address owner_) Ownable(owner_) {
        // Requirements: the roles contract address is not zero
        require(_roles != address(0), Pauser_AddressNotValid());

        // Requirements: the operator contract address is not zero
        require(_operator != address(0), Pauser_AddressNotValid());

        // Effects: set the roles and operator
        ROLES = IRoles(_roles);

        // Effects: set the operator
        OPERATOR = IOperator(_operator);
    }

    // ----------- OWNER ------------
    /// @notice Add pausable contract
    /// @param _contract the pausable contract
    /// @param _contractType the pausable contract type
    function addPausableMarket(address _contract, PausableType _contractType) external onlyOwner {
        // Requirements: the contract address is not zero
        require(_contract != address(0), Pauser_AddressNotValid());

        // If the contract is already registered, return
        if (registeredContracts[_contract]) return;

        // Effects: register the contract
        registeredContracts[_contract] = true;

        // Effects: add the contract to the pausable contracts array
        pausableContracts.push(PausableContract({market: _contract, contractType: _contractType}));

        // Effects: set the contract type
        contractTypes[_contract] = _contractType;

        // Events: emit the market added event
        emit MarketAdded(_contract, _contractType);
    }

    /// @notice Removes pausable contract
    /// @param _contract the pausable contract
    function removePausableMarket(address _contract) external onlyOwner {
        // Requirements: the contract is registered
        require(registeredContracts[_contract], Pauser_EntryNotFound());

        // Interactions: find the index of the contract
        uint256 index = _findIndex(_contract);

        // Effects: remove the contract from the pausable contracts array
        pausableContracts[index] = pausableContracts[pausableContracts.length - 1];
        pausableContracts.pop();

        // Effects: unregister the contract
        registeredContracts[_contract] = false;

        // Effects: set the contract type to non-pausable
        contractTypes[_contract] = PausableType.NonPausable;

        // Events: emit the market removed event
        emit MarketRemoved(_contract);
    }

    // ----------- PUBLIC ------------

    /// @inheritdoc IPauser
    function emergencyPauseMarket(address _market) external {
        _pauseAllMarketOperations(_market);
    }

    /// @inheritdoc IPauser
    function emergencyPauseMarketFor(address _market, ImTokenOperationTypes.OperationType _pauseType) external {
        _pauseMarketOperation(_market, _pauseType);
    }

    /// @inheritdoc IPauser
    function emergencyPauseAll() external {
        uint256 len = pausableContracts.length;
        for (uint256 i; i < len; i++) {
            // Interactions: pause all market operations for the contract
            _pauseAllMarketOperations(pausableContracts[i].market);
        }

        // Events: emit the pause all event
        emit PauseAll();
    }

    // ----------- PRIVATE ------------
    /// @notice Pauses all market operations for a given market
    /// @param _market The market to pause
    function _pauseAllMarketOperations(address _market) private {
        // Interactions: pause all market operations for the contract
        _pauseMarketOperation(_market, OperationType.AmountIn);
        _pauseMarketOperation(_market, OperationType.AmountOut);
        _pauseMarketOperation(_market, OperationType.AmountInHere);
        _pauseMarketOperation(_market, OperationType.AmountOutHere);
        _pauseMarketOperation(_market, OperationType.Mint);
        _pauseMarketOperation(_market, OperationType.Borrow);
        _pauseMarketOperation(_market, OperationType.Transfer);
        _pauseMarketOperation(_market, OperationType.Seize);
        _pauseMarketOperation(_market, OperationType.Repay);
        _pauseMarketOperation(_market, OperationType.Redeem);
        _pauseMarketOperation(_market, OperationType.Liquidate);
        _pauseMarketOperation(_market, OperationType.Rebalancing);

        // Events: emit the market paused event
        emit MarketPaused(_market);
    }

    /// @notice Pauses a specific market operation type
    /// @param _market The market to pause
    /// @param _pauseType The operation type to pause
    function _pauseMarketOperation(address _market, ImTokenOperationTypes.OperationType _pauseType) private {
        // Interactions: perform pause logic depending on contract type
        _pause(_market, _pauseType);

        // Events: emit the market paused for event
        emit MarketPausedFor(_market, _pauseType);
    }

    /// @notice Performs pause logic depending on contract type
    /// @param _market The market address to pause
    /// @param _pauseType The operation type to pause
    function _pause(address _market, ImTokenOperationTypes.OperationType _pauseType) private {
        // Requirements: the caller is allowed to pause the market operation
        require(ROLES.isAllowedFor(msg.sender, ROLES.PAUSE_MANAGER()), Pauser_NotAuthorized());

        PausableType _type = contractTypes[_market];
        if (_type == PausableType.Host) {
            // Interactions: set the paused state for the host
            OPERATOR.setPaused(_market, _pauseType, true);
        } else if (_type == PausableType.Extension) {
            // Interactions: set the paused state for the extension
            ImTokenGateway(_market).setPaused(_pauseType, true);
        } else {
            // Requirements: the contract is not enabled
            revert Pauser_ContractNotEnabled();
        }
    }

    /// @notice Finds the index of a market within the pausableContracts array
    /// @param _address The market address to search for
    /// @return index The index of the market
    function _findIndex(address _address) private view returns (uint256) {
        uint256 len = pausableContracts.length;
        for (uint256 i; i < len; i++) {
            if (pausableContracts[i].market == _address) return i;
        }
        revert Pauser_EntryNotFound();
    }
}
