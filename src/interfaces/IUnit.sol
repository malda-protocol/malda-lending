// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IUnitAccess {
    /**
     * @notice Administrator for this contract
     */
    function admin() external view returns (address);
    /**
     * @notice Pending administrator for this contract
     */
    function pendingAdmin() external view returns (address);

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function acceptAdmin() external;
}

interface IUnit {
    /**
     * @notice Active brains of Unit
     */
    function operatorImplementation() external view returns (address);

    /**
     * @notice Pending brains of Unit
     */
    function pendingOperatorImplementation() external view returns (address);

    /**
     * @notice Accepts new implementation of Operator. msg.sender must be pendingImplementation
     * @dev Admin function for new implementation to accept it's role as implementation
     */
    function acceptImplementation() external;
}
