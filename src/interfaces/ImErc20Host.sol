// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {ImTokenLogs} from "./ImTokenLogs.sol";

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

    struct LiquidateData {
        address msgSender;
        int32 srcNonce;
        int32 nonce;
        uint256 accAmount;
        uint32 srcChainId;
        uint32 chainId;
        uint256 amount;
    }
    // ----------- EVENTS -----------
    /**
     * @notice Emitted when a liquidate operation is executed
     */

    event mErc20Host_LiquidateExternal(
        address indexed liquidator, address indexed borrower, address indexed collateral, LiquidateData liquidateData
    );

    /**
     * @notice Emitted when a mint operation is executed
     */
    event mErc20Host_MintExternal(
        address msgSender,
        address indexed srcSender,
        address indexed user,
        int32 srcNonce,
        int32 nonce,
        uint256 accAmount,
        uint32 srcChainId,
        uint32 chainId,
        uint256 amount
    );

    /**
     * @notice Emitted when a borrow operation is executed
     */
    event mErc20Host_BorrowExternal(
        address msgSender,
        address indexed srcSender,
        address indexed user,
        int32 srcNonce,
        int32 nonce,
        uint256 accAmount,
        uint32 srcChainId,
        uint32 chainId,
        uint256 amount
    );

    /**
     * @notice Emitted when a repay operation is executed
     */
    event mErc20Host_RepayExternal(
        address msgSender,
        address indexed srcSender,
        address indexed user,
        int32 srcNonce,
        int32 nonce,
        uint256 accAmount,
        uint32 srcChainId,
        uint32 chainId,
        uint256 amount
    );

    /**
     * @notice Emitted when a withdrawal is executed
     */
    event mErc20Host_WithdrawExternal(
        address msgSender,
        address indexed srcSender,
        address indexed user,
        int32 srcNonce,
        int32 nonce,
        uint256 accAmount,
        uint32 srcChainId,
        uint32 chainId,
        uint256 amount
    );

    /**
     * @notice Emitted when a borrow operation is triggered for an extension chain
     */
    event mErc20Host_BorrowOnExternsionChain(
        address indexed from,
        address indexed user,
        int32 srcNonce,
        int32 dstNonce,
        uint256 accAmount,
        uint32 srcChainId,
        uint32 dstChainId,
        uint256 amount
    );

    /**
     * @notice Emitted when a withdraw operation is triggered for an extension chain
     */
    event mErc20Host_WithdrawOnExtensionChain(
        address indexed from,
        address indexed user,
        int32 srcNonce,
        int32 dstNonce,
        uint256 accAmount,
        uint32 srcChainId,
        uint32 dstChainId,
        uint256 amount
    );

    // ----------- ERRORS -----------
    /**
     * @notice Thrown when the amount provided is bigger than the available amount`
     */
    error mErc20Host_AmountTooBig();

    /**
     * @notice Thrown when the amount specified is invalid (e.g., zero)
     */
    error mErc20Host_AmountNotValid();

    /**
     * @notice Thrown when the journal data provided is invalid or corrupted
     */
    error mErc20Host_JournalNotValid();

    /**
     * @notice Thrown when caller is not allowed
     */
    error mErc20Host_CallerNotAllowed();

    // ----------- VIEW -----------
    /**
     * @notice Returns nonce
     */
    function nonce() external view returns (uint32);

    /**
     * @notice Logs manager
     */
    function logsOperator() external view returns (ImTokenLogs);

    // ----------- PUBLIC -----------
    /**
     * @notice Mints tokens after external verification
     * @param journalData The journal data for minting
     * @param seal The Zk proof seal
     * @param liquidateAmount The amount to liquidate
     * @param collateral The collateral to seize
     */
    function liquidateExternal(
        bytes calldata journalData,
        bytes calldata seal,
        uint256 liquidateAmount,
        address collateral
    ) external;

    /**
     * @notice Mints tokens after external verification
     * @param journalData The journal data for minting
     * @param seal The Zk proof seal
     * @param mintAmount The amount to mint
     */
    function mintExternal(bytes calldata journalData, bytes calldata seal, uint256 mintAmount) external;

    /**
     * @notice Borrows tokens after external verification
     * @param journalData The journal data for borrowing
     * @param seal The Zk proof seal
     * @param borrowAmount The amount to borrow
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal, uint256 borrowAmount) external;

    /**
     * @notice Repays tokens after external verification
     * @param journalData The journal data for repayment
     * @param seal The Zk proof seal
     * @param repayAmount The amount to repay
     */
    function repayExternal(bytes calldata journalData, bytes calldata seal, uint256 repayAmount) external;

    /**
     * @notice Withdraws tokens after external verification
     * @param journalData The journal data for withdrawing
     * @param seal The Zk proof seal
     * @param amount The amount to withdraw
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal, uint256 amount) external;

    /**
     * @notice Initiates a withdraw operation
     * @param amount The amount to withdraw
     * @param dstChainId The destination chain to recieve funds
     * @param allowedCallers The allowed callers for destination chain finalization
     */
    function withdrawOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers) external;

    /**
     * @notice Initiates a withdraw operation
     * @param amount The amount to withdraw
     * @param dstChainId The destination chain to recieve funds
     * @param allowedCallers The allowed callers for destination chain finalization
     */
    function borrowOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers) external;
}
