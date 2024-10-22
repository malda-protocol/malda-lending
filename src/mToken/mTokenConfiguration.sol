// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IRoles} from "../interfaces/IRoles.sol";
import {IOperator} from "../interfaces/IOperator.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";

import {mTokenStorage} from "./mTokenStorage.sol";

abstract contract mTokenConfiguration is mTokenStorage {
    // ----------- MODIFIERS ------------
    modifier onlyAdmin() {
        require(msg.sender == admin, mToken_OnlyAdmin());
        _;
    }

    // ----------- OWNER ------------
    /**
     * @notice Sets a new Operator for the market
     * @dev Admin function to set a new operator
     */
    function setOperator(address _operator) external onlyAdmin {
        _setOperator(_operator);
    }

    /**
     * @notice Sets a new Operator for the market
     * @dev Admin function to set a new operator
     */
    function setRolesOperator(address _roles) external onlyAdmin {
        require(_roles != address(0), mToken_InvalidInput());

        emit NewRolesOperator(address(rolesOperator), _roles);

        rolesOperator = IRoles(_roles);
    }

    /**
     * @notice accrues interest and updates the interest rate model using _setInterestRateModelFresh
     * @dev Admin function to accrue interest and update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     */
    function setInterestRateModel(address newInterestRateModel) external onlyAdmin {
        _accrueInterest();
        // emits interest-rate-model-update-specific logs on errors, so we don't need to.
        return _setInterestRateModel(newInterestRateModel);
    }

    /**
     * @notice accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh
     * @dev Admin function to accrue interest and set a new reserve factor
     */
    function setReserveFactor(uint256 newReserveFactorMantissa) external onlyAdmin {
        _accrueInterest();

        require(accrualBlockNumber == _getBlockNumber(), mToken_BlockNumberNotValid());

        require(newReserveFactorMantissa <= RESERVE_FACTOR_MAX_MANTISSA, mToken_ReserveFactorTooHigh());

        emit NewReserveFactor(reserveFactorMantissa, newReserveFactorMantissa);
        reserveFactorMantissa = newReserveFactorMantissa;
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function setPendingAdmin(address payable newPendingAdmin) external onlyAdmin {
        // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function acceptAdmin() external {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(msg.sender == pendingAdmin && msg.sender != address(0), mToken_OnlyAdmin());

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = payable(address(0));

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    // ----------- INTERNAL ------------
    /**
     * @notice updates the interest rate model (*requires fresh interest accrual)
     * @dev Admin function to update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     */
    function _setInterestRateModel(address newInterestRateModel) internal onlyAdmin {
        // We fail gracefully unless market's block number equals current block number
        require(accrualBlockNumber == _getBlockNumber(), mToken_BlockNumberNotValid());

        // Ensure invoke newInterestRateModel.isInterestRateModel() returns true
        require(IInterestRateModel(newInterestRateModel).isInterestRateModel(), mToken_MarketMethodNotValid());

        emit NewMarketInterestRateModel(interestRateModel, newInterestRateModel);
        interestRateModel = newInterestRateModel;
    }

    function _setOperator(address _operator) internal {
        require(IOperator(_operator).isOperator(), mToken_MarketMethodNotValid());

        emit NewOperator(operator, _operator);

        operator = _operator;
    }
}
