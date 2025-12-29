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

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";

import {mTokenStorage} from "./mTokenStorage.sol";

/// @title mTokenConfiguration
/// @author Merge Layers Inc.
/// @notice Configuration helpers for mToken markets
abstract contract mTokenConfiguration is mTokenStorage {
    // ----------- MODIFIERS ------------
    modifier onlyAdmin() {
        require(msg.sender == admin, mt_OnlyAdmin());
        _;
    }

    // ----------- OWNER ------------
    /// @notice Sets a new Operator for the market
    /// @param _operator The new operator address
    function setOperator(address _operator) external onlyAdmin {
        _setOperator(_operator);
    }

    /// @notice Sets a new Roles operator for the market
    /// @param _roles The roles contract address
    function setRolesOperator(address _roles) external onlyAdmin {
        // Requirements: the roles are not zero address
        require(_roles != address(0), mt_AddressNotValid());

        // Events: emit the roles operator updated event
        emit NewRolesOperator(address(rolesOperator), _roles);

        // Effects: set the roles operator
        rolesOperator = IRoles(_roles);
    }

    /// @notice Accrues interest and updates the interest rate model using _setInterestRateModelFresh
    /// @param newInterestRateModel The new interest rate model to use
    function setInterestRateModel(address newInterestRateModel) external onlyAdmin {
        // Effects: accrue interest
        _accrueInterest();

        // Effects: set the interest rate model
        // emits interest-rate-model-update-specific logs on errors, so we don't need to.
        return _setInterestRateModel(newInterestRateModel);
    }

    /// @notice Sets the maximum borrow rate mantissa
    /// @param maxMantissa The new max mantissa
    function setBorrowRateMaxMantissa(uint256 maxMantissa) external onlyAdmin {
        uint256 _oldVal = borrowRateMaxMantissa;

        // Effects: set the borrow rate max mantissa
        borrowRateMaxMantissa = maxMantissa;

        // Effects: if the total supply is greater than zero, accrue interest (validates new mantissa as well)
        if (totalSupply > 0) {
            _accrueInterest();
        }

        // Events: emit the new borrow rate max mantissa event
        emit NewBorrowRateMaxMantissa(_oldVal, maxMantissa);
    }

    /// @notice Accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh
    /// @dev Admin function to accrue interest and set a new reserve factor
    /// @param newReserveFactorMantissa The new reserve factor mantissa
    function setReserveFactor(uint256 newReserveFactorMantissa) external onlyAdmin {
        // Effects: accrue interest
        _accrueInterest();

        // Requirements: the new reserve factor mantissa is less than the max reserve factor mantissa
        require(newReserveFactorMantissa <= RESERVE_FACTOR_MAX_MANTISSA, mt_ReserveFactorTooHigh());

        // Events: emit the new reserve factor event
        emit NewReserveFactor(reserveFactorMantissa, newReserveFactorMantissa);

        // Effects: set the reserve factor mantissa
        reserveFactorMantissa = newReserveFactorMantissa;
    }

    /// @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
    /// @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
    /// @param newPendingAdmin New pending admin.
    function setPendingAdmin(address payable newPendingAdmin) external onlyAdmin {
        // Requirements: the new pending admin is not zero address
        require(newPendingAdmin != address(0), mt_AddressNotValid());

        // Effects: set the pending admin
        pendingAdmin = newPendingAdmin;

        // Events: emit the pending admin updated event
        emit NewPendingAdmin(newPendingAdmin);
    }

    /// @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
    /// @dev Admin function for pending admin to accept role and update admin
    function acceptAdmin() external {
        // Requirements: the caller is the pending admin
        require(msg.sender == pendingAdmin, mt_OnlyAdmin());

        // Effects: set the admin
        admin = pendingAdmin;

        // Effects: clear the pending admin
        pendingAdmin = payable(address(0));

        // Events: emit the admin updated event
        emit AdminAccepted(admin);
    }

    // ----------- INTERNAL ------------
    /// @notice Updates the interest rate model (*requires fresh interest accrual)
    /// @dev Admin function to update the interest rate model
    /// @param newInterestRateModel The new interest rate model to use
    function _setInterestRateModel(address newInterestRateModel) internal {
        // Requirements: ensure invoking newInterestRateModel.isInterestRateModel() returns true
        require(IInterestRateModel(newInterestRateModel).isInterestRateModel(), mt_MarketMethodNotValid());

        // Events: emit the new interest rate model event
        emit NewMarketInterestRateModel(interestRateModel, newInterestRateModel);

        // Effects: set the interest rate model
        interestRateModel = newInterestRateModel;
    }

    /// @notice Sets the Operator contract address
    /// @param _operator The operator address
    function _setOperator(address _operator) internal {
        // Requirements: the operator is not zero address
        require(_operator != address(0), mt_OperatorNotValid());

        // Events: emit the operator updated event
        emit NewOperator(operator, _operator);

        // Effects: set the operator
        operator = _operator;
    }
}
