// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IRoles {
    /**
     * @notice returns allowance status for a contract and a role
     * @param _contract the contract address
     * @param _role the bytes32 role
     */
    function allowedFor(address _contract, bytes32 _role) external view returns (bool);
}
