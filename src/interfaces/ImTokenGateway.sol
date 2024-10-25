// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                          
*/

interface ImTokenGateway {
    // ----------- STRUCTS -----------
    enum ImageIdIndexes {
        Release
    }

    enum OperationType {
        Mint,
        Borrow,
        Repay,
        Withdraw,
        Release
    }

    struct LogData {
        uint256 nonce;
        bytes data;
    }

    // ----------- EVENTS -----------

    /**
     * @notice Emitted when a mint operation is initiated
     * @param from The address of the user initiating the mint
     * @param amount The amount of tokens to mint
     * @param nonce The nonce for this operation
     */
    event mTokenGateway_MintInitiated(address indexed from, uint256 amount, uint256 nonce);

    /**
     * @notice Emitted when a borrow operation is initiated
     * @param from The address of the user initiating the borrow
     * @param amount The amount to borrow
     * @param nonce The nonce for this operation
     */
    event mTokenGateway_BorrowInitiated(address indexed from, uint256 amount, uint256 nonce);

    /**
     * @notice Emitted when a repay operation is initiated
     * @param from The address of the user initiating the repayment
     * @param amount The amount to repay
     * @param nonce The nonce for this operation
     */
    event mTokenGateway_RepayInitiated(address indexed from, uint256 amount, uint256 nonce);

    /**
     * @notice Emitted when a withdrawal is initiated
     * @param from The address of the user initiating the withdrawal
     * @param amount The amount to withdraw
     * @param nonce The nonce for this operation
     */
    event mTokenGateway_WithdrawInitiated(address indexed from, uint256 amount, uint256 nonce);

    /**
     * @notice Emitted when a release operation is executed
     * @param from The address of the user receiving the released tokens
     * @param amount The amount of tokens released
     * @param nonce The nonce for this operation
     */
    event mTokenGateway_Released(address indexed from, uint256 amount, uint256 nonce);

    // ----------- ERRORS -----------

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

    // ----------- VIEW -----------
    /**
     * @notice Returns the address of the underlying token
     * @return The address of the underlying token
     */
    function underlying() external view returns (address);

    /**
     * @notice Retrieves the current nonce for a user and operation type
     * @param user The address of the user
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @return The current nonce for the specified user and operation type
     */
    function getNonce(address user, OperationType opType) external view returns (uint256);

    /**
     * @notice Retrieves log data for a specific user, operation type, and index
     * @param user The address of the user
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @param index The index of the log entry
     * @return The LogData struct containing the nonce and associated data
     */
    function getLogsAt(address user, OperationType opType, uint256 index) external view returns (LogData memory);

    /**
     * @notice Returns the number of log entries for a user and operation type
     * @param user The address of the user
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @return The number of log entries for the specified user and operation type
     */
    function getLogsLength(address user, OperationType opType) external view returns (uint256);

    /**
     * @notice Retrieves the pending amount for a user
     * @param user The address of the user
     * @return The pending amount for the specified user
     */
    function pendingAmounts(address user) external view returns (uint256);

    /**
     * @notice Retrieves the current nonce for a user and a specific operation type
     * @param user The address of the user
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @return The nonce for the specified user and operation type
     */
    function nonces(address user, OperationType opType) external view returns (uint256);

    // ----------- PUBLIC -----------

    /**
     * @notice Mints new tokens by transferring the underlying token from the user
     * @param amount The amount of tokens to mint
     */
    function mint(uint256 amount) external;

    /**
     * @notice Initiates a borrowing operation
     * @param amount The amount to borrow
     */
    function borrow(uint256 amount) external;

    /**
     * @notice Repays a borrowed amount by transferring the underlying token from the user
     * @param amount The amount to repay
     */
    function repay(uint256 amount) external;

    /**
     * @notice Withdraws tokens and burns the corresponding minted tokens
     * @param amount The amount to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Releases tokens to a user based on a validated zk-proof and journal data
     * @param journalData The journal data containing the release information
     * @param seal The zk-proof data required to verify the release
     */
    function release(bytes calldata journalData, bytes calldata seal) external;
}
