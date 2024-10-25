// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IRoles {
    enum Pause {
        Mint,
        Borrow,
        Transfer,
        Seize,
        Repay,
        Redeem
    }

    /**
     * @notice Returns GUARDIAN_PAUSE role
     */
    function GUARDIAN_PAUSE() external view returns (bytes32);

    /**
     * @notice Returns GUARDIAN_TRANSFER role
     */
    function GUARDIAN_TRANSFER() external view returns (bytes32);

    /**
     * @notice Returns GUARDIAN_SEIZE role
     */
    function GUARDIAN_SEIZE() external view returns (bytes32);

    /**
     * @notice Returns GUARDIAN_MINT role
     */
    function GUARDIAN_MINT() external view returns (bytes32);

    /**
     * @notice Returns GUARDIAN_BORROW role
     */
    function GUARDIAN_BORROW() external view returns (bytes32);

    /**
     * @notice Returns GUARDIAN_BORROW_CAP role
     */
    function GUARDIAN_BORROW_CAP() external view returns (bytes32);

    /**
     * @notice Returns GUARDIAN_SUPPLY_CAP role
     */
    function GUARDIAN_SUPPLY_CAP() external view returns (bytes32);

    /**
     * @notice Returns GUARDIAN_RESERVE role
     */
    function GUARDIAN_RESERVE() external view returns (bytes32);

    /**
     * @notice Returns allowance status for a contract and a role
     * @param _contract the contract address
     * @param _role the bytes32 role
     */
    function isAllowedFor(address _contract, bytes32 _role) external view returns (bool);
}
