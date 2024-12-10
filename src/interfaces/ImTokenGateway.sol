// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                          
*/

import {IRoles} from "./IRoles.sol";
import {ImTokenLogs} from "./ImTokenLogs.sol";
import {ImTokenOperationTypes} from "./ImToken.sol";

interface ImTokenGateway {
    // ----------- EVENTS -----------
    /**
     * @notice Emitted when a supply operation is initiated
     */
    event mTokenGateway_Supplied(
        address indexed from,
        address indexed user,
        uint256 amount,
        int32 srcNonce,
        int32 dstNonce,
        uint256 accAmountIn,
        uint32 srcChainId,
        uint32 dstChainId
    );
    /**
     * @notice Emitted when a supply operation is initiated
     */
    event mTokenGateway_OutOnHost(
        address indexed from,
        address indexed user,
        uint256 amount,
        int32 srcNonce,
        int32 dstNonce,
        uint256 accAmountIn,
        uint32 srcChainId,
        uint32 dstChainId
    );
    /**
     * @notice Emitted when an extract was finalized
     */
    event mTokenGateway_Extracted(
        address indexed msgSender,
        address indexed srcSender,
        address indexed srcUser,
        uint256 amount,
        int32 srcNonce,
        int32 dstNonce,
        uint256 accAmountOut,
        uint32 srcChainId,
        uint32 dstChainId
    );

    // ----------- ERRORS -----------
    /**
     * @notice Thrown when the address is not valid
     */
    error mTokenGateway_AddressNotValid();
    /**
     * @notice Thrown when the amount specified is invalid (e.g., zero)
     */
    error mTokenGateway_AmountNotValid();

    /**
     * @notice Thrown when the journal data provided is invalid
     */
    error mTokenGateway_JournalNotValid();

    /**
     * @notice Thrown when there is insufficient cash to release the specified amount
     */
    error mTokenGateway_AmountTooBig();

    /**
     * @notice Thrown when there is insufficient cash to release the specified amount
     */
    error mTokenGateway_ReleaseCashNotAvailable();

    /**
     * @notice Thrown when token is tranferred
     */
    error mTokenGateway_NonTransferable();

    /**
     * @notice Thrown when caller is not allowed
     */
    error mTokenGateway_CallerNotAllowed();

    /**
     * @notice Thrown when market is paused for operation type
     */
    error mTokenGateway_Paused(ImTokenOperationTypes.OperationType _type);

    // ----------- VIEW -----------
    /**
     * @notice Roles manager
     */
    function rolesOperator() external view returns (IRoles);

    /**
     * @notice Logs manager
     */
    function logsOperator() external view returns (ImTokenLogs);

    /**
     * @notice Returns the address of the underlying token
     * @return The address of the underlying token
     */
    function underlying() external view returns (address);

    /**
     * @notice returns pause state for operation
     * @param _type the operation type
     */
    function isPaused(ImTokenOperationTypes.OperationType _type) external view returns (bool);

    /**
     * @notice Returns nonce
     */
    function nonce() external view returns (uint32);

    /**
     * @notice Returns accumulated amount in per user
     */
    function accAmountIn(address user) external view returns (uint256);

    /**
     * @notice Returns accumulated amount out per user
     */
    function accAmountOut(address user) external view returns (uint256);

    // ----------- PUBLIC -----------
    /**
     * @notice Set pause for a specific operation
     * @param _type The pause operation type
     * @param state The pause operation status
     */
    function setPaused(ImTokenOperationTypes.OperationType _type, bool state) external;

    /**
     * @notice Supply underlying to the contractr
     * @param amount The supplied amount
     * @param user The user to supply for
     * @param allowedCallers The allowed callers for host chain interactions
     */
    function supplyOnHost(uint256 amount, address user, address[] calldata allowedCallers) external;

    /**
     * @notice Supply underlying to the contractr
     * @param amount The supplied amount
     * @param user The user to supply for
     * @param allowedCallers The allowed callers for host chain interactions
     */
    function outOnHost(uint256 amount, address user, address[] calldata allowedCallers) external;

    /**
     * @notice Extract tokens
     * @param journalData The supplied journal
     * @param seal The seal address
     * @param amount The amount to use
     */
    function outHere(bytes calldata journalData, bytes calldata seal, uint256 amount) external;
}
