// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {IUnit, IUnitAccess} from "src/interfaces/IUnit.sol";

contract Unit is IUnit, IUnitAccess {
    // ----------- STORAGE ------------
    /**
     * @inheritdoc IUnitAccess
     */
    address public admin;

    /**
     * @inheritdoc IUnitAccess
     */
    address public pendingAdmin;

    /**
     * @inheritdoc IUnit
     */
    address public operatorImplementation;

    /**
     * @inheritdoc IUnit
     */
    address public pendingOperatorImplementation;

    // ----------- ERRORS ------------
    error Unit_OnlyAdmin();

    // ----------- EVENTS ------------
    /**
     * @notice Emitted when pendingOperatorImplementation is changed
     */
    event NewPendingImplementation(address oldPendingImplementation, address newPendingImplementation);

    /**
     * @notice Emitted when pendingOperatorImplementation is accepted, which means Operator implementation is updated
     */
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
     * @notice Emitted when pendingAdmin is changed
     */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
     * @notice Emitted when pendingAdmin is accepted, which means admin is updated
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    // ----------- MODIFIERS ------------
    modifier onlyAdmin() {
        require(msg.sender == admin, Unit_OnlyAdmin());
        _;
    }

    constructor(address _admin) {
        // Set admin to caller
        admin = _admin;
    }

    // ----------- OWNER ------------
    /**
     * @notice Sets a pending implementation
     * @param newPendingImplementation The new implementation address
     */
    function setPendingImplementation(address newPendingImplementation) external onlyAdmin {
        emit NewPendingImplementation(pendingOperatorImplementation, newPendingImplementation);
        pendingOperatorImplementation = newPendingImplementation;
    }

    /**
     * @inheritdoc IUnit
     */
    function acceptImplementation() external override {
        // Check caller is pendingImplementation and pendingImplementation ≠ address(0)
        require(msg.sender == pendingOperatorImplementation && msg.sender != address(0), Unit_OnlyAdmin());
        // Check caller is pendingImplementation and pendingImplementation ≠ address(0)

        // Save current values for inclusion in log
        address oldImplementation = operatorImplementation;
        address oldPendingImplementation = pendingOperatorImplementation;

        operatorImplementation = pendingOperatorImplementation;

        pendingOperatorImplementation = address(0);

        emit NewImplementation(oldImplementation, operatorImplementation);
        emit NewPendingImplementation(oldPendingImplementation, pendingOperatorImplementation);
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function setPendingAdmin(address newPendingAdmin) external onlyAdmin {
        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);
        pendingAdmin = newPendingAdmin;
    }

    /**
     * @inheritdoc IUnitAccess
     */
    function acceptAdmin() external override {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        require(msg.sender == pendingAdmin && msg.sender != address(0), Unit_OnlyAdmin());

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    /**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    fallback() external payable {
        // delegate all other functions to current implementation
        (bool success,) = operatorImplementation.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())

            switch success
            case 0 { revert(free_mem_ptr, returndatasize()) }
            default { return(free_mem_ptr, returndatasize()) }
        }
    }

    receive() external payable {}
}
