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
     * @notice Emitted when a liquidate operation is initiated
     */
    event mTokenGateway_LiquidateInitiated(
        address indexed liquidator,
        address indexed user,
        address indexed collateral,
        uint256 amount,
        uint32 nonce,
        uint32 chainId
    );

    /**
     * @notice Emitted when a mint operation is initiated
     */
    event mTokenGateway_MintInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);

    /**
     * @notice Emitted when a borrow operation is initiated
     */
    event mTokenGateway_BorrowInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);

    /**
     * @notice Emitted when a repay operation is initiated
     */
    event mTokenGateway_RepayInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);

    /**
     * @notice Emitted when a withdrawal is initiated
     */
    event mTokenGateway_WithdrawInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);

    /**
     * @notice Emitted when a release operation is executed
     */
    event mTokenGateway_Released(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);

    /**
     * @notice Emitted when a borrow operation is finalized
     */
    event mTokenGateway_BorrowExternal(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);

    // ----------- ERRORS -----------
    /**
     * @notice Thrown when the address is not valid
     */
    error mTokenGateway_AddressNotValid();

    /**
     * @notice Thrown when the amount specified is too large for the operation
     */
    error mTokenGateway_AmountTooBig();

    /**
     * @notice Thrown when the nonce provided is invalid for the operation
     */
    error mTokenGateway_NonceNotValid();

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
     * @notice Retrieves the current nonce for a user and operation type
     * @param user The address of the user
     * @param chainId The chainId to get the data for
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @return The current nonce for the specified user and operation type
     */
    function getNonce(address user, uint32 chainId, ImTokenOperationTypes.OperationType opType)
        external
        view
        returns (uint32);

    /**
     * @notice Retrieves the current nonce for a user and a specific operation type
     * @param user The address of the user
     * @param chainId The chainId to get the data for
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @return The nonce for the specified user and operation type
     */
    function nonces(address user, uint32 chainId, ImTokenOperationTypes.OperationType opType)
        external
        view
        returns (uint32);

    /**
     * @notice returns pause state for operation
     * @param _type the operation type
     */
    function isPaused(ImTokenOperationTypes.OperationType _type) external view returns (bool);

    // ----------- PUBLIC -----------
    /**
     * @notice Set pause for a specific operation
     * @param _type The pause operation type
     * @param state The pause operation status
     */
    function setPaused(ImTokenOperationTypes.OperationType _type, bool state) external;

    /**
     * @notice Initiates a liquidation request to be fulfilled on host
     * @dev `collateral` can be address(0)
     * @param amount The amount of tokens to liquidate
     * @param user The position to liquidate
     * @param collateral The collateral to receive
     */
    function liquidateOnHost(uint256 amount, address user, address collateral) external;

    /**
     * @notice Mints new tokens by transferring the underlying token from the user
     * @param amount The amount of tokens to mint
     */
    function mintOnHost(uint256 amount) external;

    /**
     * @notice Initiates a borrowing operation
     * @param amount The amount to borrow
     */
    function borrowOnHost(uint256 amount) external;

    /**
     * @notice Finalizes a borrow action initiated from host chain
     * @param journalData The journal data containing the release information
     * @param seal The zk-proof data required to verify the release
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Repays a borrowed amount by transferring the underlying token from the user
     * @param amount The amount to repay
     */
    function repayOnHost(uint256 amount) external;

    /**
     * @notice Withdraws tokens and burns the corresponding minted tokens
     * @param amount The amount to withdraw
     */
    function withdrawOnHost(uint256 amount) external;

    /**
     * @notice Releases tokens to a user based on a validated zk-proof and journal data
     * @param journalData The journal data containing the release information
     * @param seal The zk-proof data required to verify the release
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal) external;
}
