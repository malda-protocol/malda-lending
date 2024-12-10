// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {ImTokenLogs} from "./ImTokenLogs.sol";
import {ImTokenOperationTypes} from "./ImToken.sol";

interface ImErc20Host {
    struct InitData {
        address underlyingToken;
        address operator;
        address interestModel;
        uint256 exchaneRateMantissa;
        string name;
        string symbol;
        uint8 decimals;
        address zkVerifier;
        address imageRegistry;
        address owner;
    }
    // ----------- EVENTS -----------
    /**
     * @notice Emitted when a liquidate operation is executed
     */

    event mErc20Host_LiquidateExternal(
        address indexed liquidator,
        address indexed user,
        address indexed collateral,
        uint256 amount,
        uint32 nonce,
        uint32 chainId
    );

    /**
     * @notice Emitted when a mint operation is executed
     */
    event mErc20Host_MintExternal(
        address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
    );

    /**
     * @notice Emitted when a borrow operation is executed
     */
    event mErc20Host_BorrowExternal(
        address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
    );

    /**
     * @notice Emitted when a borrow operation is triggered for an extension chain
     */
    event mErc20Host_BorrowOnExternsionChain(
        address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
    );

    /**
     * @notice Emitted when a repay operation is executed
     */
    event mErc20Host_RepayExternal(
        address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
    );

    /**
     * @notice Emitted when a withdrawal is executed
     */
    event mErc20Host_WithdrawExternal(
        address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
    );

    /**
     * @notice Emitted when a withdraw operation is triggered for an extension chain
     */
    event mErc20Host_WithdrawOnExtensionChain(
        address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
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
     * @notice Logs manager
     */
    function logsOperator() external view returns (ImTokenLogs);

    /**
     * @notice Retrieves the current nonce for a user and operation type
     * @param user The address of the user
     * @param chainId The chainId to get the data for
     * @param opType The operation type (Mint, Borrow, Repay, Redeem)
     * @return The current nonce for the specified user and operation type
     */
    function getNonce(address user, uint32 chainId, ImTokenOperationTypes.OperationType opType)
        external
        view
        returns (uint32);

    // ----------- PUBLIC -----------
    /**
     * @notice Mints tokens after external verification
     * @param journalData The journal data for minting
     * @param seal The Zk proof seal
     */
    function liquidateExternal(bytes calldata journalData, bytes calldata seal) external;

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
