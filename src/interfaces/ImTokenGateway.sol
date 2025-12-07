// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This file contains code derived from or inspired by Compound V2,
// originally licensed under the BSD 3-Clause License. See LICENSE-COMPOUND-V2
// for original license terms and attributions.

// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

import {IRoles} from "./IRoles.sol";
import {IBlacklister} from "./IBlacklister.sol";
import {ImTokenOperationTypes} from "./ImToken.sol";

/// @title ImTokenGateway
/// @author Merge Layers Inc.
/// @notice Gateway interface for cross-chain mToken operations
interface ImTokenGateway {
    // ----------- EVENTS -----------

    /// @notice Emitted when a user updates allowed callers
    /// @param sender The caller updating permissions
    /// @param caller The address whose status is updated
    /// @param status Whether the caller is allowed
    event AllowedCallerUpdated(address indexed sender, address indexed caller, bool status);

    /// @notice Emitted when a supply operation is initiated
    /// @param from Sender on source chain
    /// @param receiver Receiver on destination
    /// @param accAmountIn Accumulated amount in
    /// @param accAmountOut Accumulated amount out
    /// @param amount Supplied amount
    /// @param srcChainId Source chain ID
    /// @param dstChainId Destination chain ID
    /// @param lineaMethodSelector Linea method selector
    event mTokenGateway_Supplied(
        address indexed from,
        address indexed receiver,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint256 amount,
        uint32 srcChainId,
        uint32 dstChainId,
        bytes4 lineaMethodSelector
    );

    /// @notice Emitted when a liquidate operation is initiated
    /// @param from Sender on source chain
    /// @param receiver Receiver of seized collateral
    /// @param amount Liquidation amount
    /// @param srcChainId Source chain ID
    /// @param dstChainId Destination chain ID
    /// @param userToLiquidate User being liquidated
    /// @param collateral Collateral market address
    event mTokenGateway_Liquidate(
        address indexed from,
        address indexed receiver,
        uint256 amount,
        uint32 srcChainId,
        uint32 dstChainId,
        address userToLiquidate,
        address collateral
    );

    /// @notice Emitted when an extract was finalized
    /// @param msgSender Sender on host chain
    /// @param srcSender Sender on source chain
    /// @param receiver Receiver of funds
    /// @param accAmountIn Accumulated amount in
    /// @param accAmountOut Accumulated amount out
    /// @param amount Amount extracted
    /// @param srcChainId Source chain ID
    /// @param dstChainId Destination chain ID
    event mTokenGateway_Extracted(
        address indexed msgSender,
        address indexed srcSender,
        address indexed receiver,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint256 amount,
        uint32 srcChainId,
        uint32 dstChainId
    );

    /// @notice Emitted when a proof was skipped
    /// @param msgSender Sender on host chain
    /// @param srcSender Sender on source chain
    /// @param receiver Receiver of funds
    /// @param accAmountIn Accumulated amount in
    /// @param accAmountOut Accumulated amount out
    /// @param amount Amount skipped
    /// @param srcChainId Source chain ID
    /// @param dstChainId Destination chain ID
    event mTokenGateway_Skipped(
        address indexed msgSender,
        address indexed srcSender,
        address indexed receiver,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint256 amount,
        uint32 srcChainId,
        uint32 dstChainId
    );

    /// @notice Emitted when the gas fee is updated
    /// @param amount New gas fee amount
    event mTokenGateway_GasFeeUpdated(uint256 amount);

    /// @notice Emitted when pause state changes
    /// @param _type Operation type paused/unpaused
    /// @param _status Pause status
    event mTokenGateway_PausedState(ImTokenOperationTypes.OperationType indexed _type, bool _status);

    /// @notice Emitted when zk verifier is updated
    /// @param oldVerifier Previous verifier
    /// @param newVerifier New verifier
    event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);

    /// @notice Emitted when user whitelist status changes
    /// @param user User address
    /// @param status Whitelist status
    event mTokenGateway_UserWhitelisted(address indexed user, bool status);

    /// @notice Emitted when whitelist is enabled
    event mTokenGateway_WhitelistEnabled();

    /// @notice Emitted when whitelist is disabled
    event mTokenGateway_WhitelistDisabled();

    // ----------- ERRORS -----------+
    /// @notice Thrown when the chain id is not LINEA
    error mTokenGateway_ChainNotValid();

    /// @notice Thrown when the address is not valid
    error mTokenGateway_AddressNotValid();

    /// @notice Thrown when the amount specified is invalid (e.g., zero)
    error mTokenGateway_AmountNotValid();

    /// @notice Thrown when the journal data provided is invalid
    error mTokenGateway_JournalNotValid();

    /// @notice Thrown when there is insufficient cash to release the specified amount
    error mTokenGateway_AmountTooBig();

    /// @notice Thrown when there is insufficient cash to release the specified amount
    error mTokenGateway_ReleaseCashNotAvailable();

    /// @notice Thrown when token is tranferred
    error mTokenGateway_NonTransferable();

    /// @notice Thrown when caller is not allowed
    error mTokenGateway_CallerNotAllowed();

    /// @notice Thrown when market is paused for operation type
    error mTokenGateway_Paused(ImTokenOperationTypes.OperationType _type);

    /// @notice Thrown when caller is not rebalancer
    error mTokenGateway_NotRebalancer();

    /// @notice Thrown when length is not valid
    error mTokenGateway_LengthNotValid();

    /// @notice Thrown when not enough gas fee was received
    error mTokenGateway_NotEnoughGasFee();

    /// @notice Thrown when L1 inclusion is required
    error mTokenGateway_L1InclusionRequired();

    /// @notice Thrown when user is not whitelisted
    error mTokenGateway_UserNotWhitelisted();

    /// @notice Thrown when user is blacklisted
    error mTokenGateway_UserBlacklisted();

    // ----------- PUBLIC -----------
    /// @notice Extract amount to be used for rebalancing operation
    /// @param amount The amount to rebalance
    function extractForRebalancing(uint256 amount) external;

    /// @notice Set pause for a specific operation
    /// @param _type The pause operation type
    /// @param state The pause operation status
    function setPaused(ImTokenOperationTypes.OperationType _type, bool state) external;

    /// @notice Set caller status for `msg.sender`
    /// @param caller The caller address
    /// @param status The status to set for `caller`
    function updateAllowedCallerStatus(address caller, bool status) external;

    /// @notice Supply underlying to the contract
    /// @param amount The supplied amount
    /// @param receiver The receiver address
    /// @param lineaSelector The method selector to be called on Linea by our relayer. If empty, user has to submit it
    function supplyOnHost(uint256 amount, address receiver, bytes4 lineaSelector) external payable;

    /// @notice Liquidate a user
    /// @param userToLiquidate The user to liquidate
    /// @param liquidateAmount The amount to liquidate
    /// @param collateral The collateral address
    /// @param receiver The receiver address
    function liquidate(address userToLiquidate, uint256 liquidateAmount, address collateral, address receiver)
        external
        payable;

    /// @notice Extract tokens
    /// @param journalData The supplied journal
    /// @param seal The seal address
    /// @param amounts The amounts to withdraw for each journal
    /// @param receiver The receiver address
    function outHere(bytes calldata journalData, bytes calldata seal, uint256[] memory amounts, address receiver)
        external;

    // ----------- VIEW -----------
    /// @notice Roles
    /// @return roles Roles operator contract
    function rolesOperator() external view returns (IRoles roles);

    /// @notice Blacklist operator
    /// @return blacklister Blacklister contract
    function blacklistOperator() external view returns (IBlacklister blacklister);

    /// @notice Returns the address of the underlying token
    /// @return underlyingToken The address of the underlying token
    function underlying() external view returns (address underlyingToken);

    /// @notice Returns pause state for operation
    /// @param _type The operation type
    /// @return paused True if paused
    function isPaused(ImTokenOperationTypes.OperationType _type) external view returns (bool paused);

    /// @notice Returns accumulated amount in per user
    /// @param user User address
    /// @return amountIn Accumulated amount in
    function accAmountIn(address user) external view returns (uint256 amountIn);

    /// @notice Returns accumulated amount out per user
    /// @param user User address
    /// @return amountOut Accumulated amount out
    function accAmountOut(address user) external view returns (uint256 amountOut);

    /// @notice Returns the proof data journal
    /// @param user User address
    /// @param dstId Destination chain identifier
    /// @return dataRoot The proof data root
    /// @return journalHash The proof journal hash
    function getProofData(address user, uint32 dstId) external view returns (uint256 dataRoot, uint256 journalHash);

    /// @notice Returns the gas fee for Linea
    /// @return fee Gas fee amount
    function gasFee() external view returns (uint256 fee);
}
