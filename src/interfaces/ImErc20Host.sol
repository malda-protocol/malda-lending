// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface ImErc20Host {
    // ----------- STRUCTS -----------
    enum ImageIdIndexes {
        Mint, // finalizes a mint operation requested from an extension chain
        Borrow, // finalizes a borrow operation requested from an extension chain
        BorrowOnExtension, // requests a borrow on an extension chain
        Repay, // finalizes a repay operation requested from an extension chain
        Redeem, // finalizes a withdraw operation requested from an extension chain
        RedeemOnExtension // requests a withdraw on an extension chain

    }

    enum OperationType {
        Mint, // finalizes a mint operation requested from an extension chain
        Borrow, // finalizes a borrow operation requested from an extension chain
        BorrowOnExtension, // requests a borrow on an extension chain
        Repay, // finalizes a repay operation requested from an extension chain
        Redeem, // finalizes a withdraw operation requested from an extension chain
        RedeemOnExtension // requests a withdraw on an extension chain

    }

    struct LogData {
        uint256 nonce;
        bytes data;
    }

    // ----------- EVENTS -----------
    /**
     * @notice Emitted when a mint operation is executed
     */
    event mErc20Host_MintExternal(
        address indexed from, address indexed user, uint256 amount, uint256 nonce, uint256 chainId
    );

    /**
     * @notice Emitted when a borrow operation is executed
     */
    event mErc20Host_BorrowExternal(
        address indexed from, address indexed user, uint256 amount, uint256 nonce, uint256 chainId
    );

    /**
     * @notice Emitted when a borrow operation is triggered for an extension chain
     */
    event mErc20Host_BorrowOnExternsionChain(
        address indexed from, address indexed user, uint256 amount, uint256 nonce, uint256 chainId
    );

    /**
     * @notice Emitted when a repay operation is executed
     */
    event mErc20Host_RepayExternal(
        address indexed from, address indexed user, uint256 amount, uint256 nonce, uint256 chainId
    );

    /**
     * @notice Emitted when a withdrawal is executed
     */
    event mErc20Host_WithdrawExternal(
        address indexed from, address indexed user, uint256 amount, uint256 nonce, uint256 chainId
    );

    /**
     * @notice Emitted when a withdraw operation is triggered for an extension chain
     */
    event mErc20Host_WithdrawOnExtensionChain(
        address indexed from, address indexed user, uint256 amount, uint256 nonce, uint256 chainId
    );

    // ----------- ERRORS -----------
    /**
     * @notice Thrown when the amount specified is invalid (e.g., zero)
     */
    error mErc20Host_AmountNotValid();

    /**
     * @notice Thrown when the journal data provided is invalid or corrupted
     */
    error mErc20Host_JournalNotValid();

    /**
     * @notice Thrown when the nonce provided is invalid or does not match the expected value
     */
    error mErc20Host_NonceNotValid();

    /**
     * @notice Thrown when caller is not allowed
     */
    error mErc20Host_CallerNotAllowed();

    // ----------- VIEW -----------
    /**
     * @notice Retrieves the current nonce for a user and operation type
     * @param user The address of the user
     * @param chainId The chainId to get the data for
     * @param opType The operation type (Mint, Borrow, Repay, Redeem)
     * @return The current nonce for the specified user and operation type
     */
    function getNonce(address user, uint256 chainId, OperationType opType) external view returns (uint256);

    /**
     * @notice Retrieves log data for a specific user, operation type, and index
     * @param user The address of the user
     * @param chainId The chainId to get the data for
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @param index The index of the log entry
     * @return The LogData struct containing the nonce and associated data
     */
    function getLogsAt(address user, uint256 chainId, OperationType opType, uint256 index)
        external
        view
        returns (LogData memory);

    /**
     * @notice Returns the number of log entries for a user and operation type
     * @param user The address of the user
     * @param chainId The chainId to get the data for
     * @param opType The operation type (Mint, Borrow, Repay, Withdraw, Release)
     * @return The number of log entries for the specified user and operation type
     */
    function getLogsLength(address user, uint256 chainId, OperationType opType) external view returns (uint256);

    // ----------- PUBLIC -----------
    /**
     * @notice Mints tokens after external verification
     * @param journalData The journal data for minting
     * @param seal The Zk proof seal
     */
    function mintExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Borrows tokens after external verification
     * @param journalData The journal data for borrowing
     * @param seal The Zk proof seal
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Initiates a borrowing operation
     * @param amount The amount to borrow
     * @param journalData The journal data for borrowing
     * @param seal The Zk proof seal
     */
    function borrowOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Repays tokens after external verification
     * @param journalData The journal data for repayment
     * @param seal The Zk proof seal
     */
    function repayExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Withdraws tokens after external verification
     * @param journalData The journal data for withdrawing
     * @param seal The Zk proof seal
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Initiates a withdraw operation
     * @param journalData The journal data for withdrawing
     * @param seal The Zk proof seal
     */
    function withdrawOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external;
}
