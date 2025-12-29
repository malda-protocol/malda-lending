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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

/// @title IRebalanceMarket
/// @author Merge Layers Inc.
/// @notice Interface for markets supporting rebalancing extractions.
interface IRebalanceMarket {
    /// @notice Extracts an amount to be used for rebalancing.
    /// @param amount Amount to extract.
    function extractForRebalancing(uint256 amount) external;
}

/// @title IRebalancer
/// @author Merge Layers Inc.
/// @notice Interface for rebalancer operations and configuration.
interface IRebalancer {
    // ----------- STORAGE ------------
    struct Msg {
        uint32 dstChainId;
        address token;
        bytes message;
        bytes bridgeData;
    }

    // ----------- EVENTS ------------

    /// @notice Emitted when bridge whitelist status changes.
    /// @param bridge Bridge address.
    /// @param status Whitelist status.
    event BridgeWhitelistedStatusUpdated(address indexed bridge, bool status);

    /// @notice Emitted when a message is sent through a bridge.
    /// @param bridge Bridge address.
    /// @param dstChainId Destination chain ID.
    /// @param token Token address.
    /// @param message Encoded message.
    /// @param bridgeData Bridge-specific data.
    event MsgSent(
        address indexed bridge, uint32 indexed dstChainId, address indexed token, bytes message, bytes bridgeData
    );

    /// @notice Emitted when ETH is saved back to treasury.
    /// @param amount Amount saved.
    event EthSaved(uint256 amount);

    /// @notice Emitted when max transfer size is updated.
    /// @param dstChainId Destination chain ID.
    /// @param token Token address.
    /// @param newLimit New limit.
    event MaxTransferSizeUpdated(uint32 indexed dstChainId, address indexed token, uint256 newLimit);

    /// @notice Emitted when min transfer size is updated.
    /// @param dstChainId Destination chain ID.
    /// @param token Token address.
    /// @param newLimit New limit.
    event MinTransferSizeUpdated(uint32 indexed dstChainId, address indexed token, uint256 newLimit);

    /// @notice Emitted when destination whitelist status changes.
    /// @param dstChainId Destination chain ID.
    /// @param status Whitelist status.
    event DestinationWhitelistedStatusUpdated(uint32 indexed dstChainId, bool status);

    /// @notice Emitted when allowed list is updated.
    /// @param list List of addresses.
    /// @param status Whitelist status.
    event AllowedListUpdated(address[] list, bool status);

    /// @notice Emitted when tokens are rescued.
    /// @param token Token address.
    /// @param market Market address.
    /// @param amount Amount saved.
    event TokensSaved(address indexed token, address indexed market, uint256 amount);

    /// @notice Emitted when allowed tokens list is updated for a bridge.
    /// @param bridge Bridge address.
    /// @param status Whitelist status.
    /// @param list Token list.
    event AllowedTokensUpdated(address indexed bridge, bool status, address[] list);

    /// @notice Emitted when the market whitelist list is updated.
    /// @param list Market list.
    /// @param status Whitelist status.
    event MarketListUpdated(address[] list, bool status);

    /// @notice Emitted when a new admin is set.
    /// @param acc New admin address.
    event NewAdmin(address indexed acc);

    // ----------- ERRORS ------------

    /// @notice Error thrown when caller not authorized.
    error Rebalancer_NotAuthorized();

    /// @notice Error thrown when market is not valid.
    error Rebalancer_MarketNotValid();

    /// @notice Error thrown when request is not valid.
    error Rebalancer_RequestNotValid();

    /// @notice Error thrown when address is not valid.
    error Rebalancer_AddressNotValid();

    /// @notice Error thrown when bridge is not whitelisted.
    error Rebalancer_BridgeNotWhitelisted();

    /// @notice Error thrown when transfer size exceeds maximum.
    error Rebalancer_TransferSizeExcedeed();

    /// @notice Error thrown when transfer size below minimum.
    error Rebalancer_TransferSizeMinNotMet();

    /// @notice Error thrown when destination not whitelisted.
    error Rebalancer_DestinationNotWhitelisted();

    /// @notice Error thrown when underlying token not allowed for bridge.
    error Rebalancer_UnderlyingNotAllowedForBridge();

    // ----------- EXTERNAL METHODS ------------

    /// @notice Sends a bridge message.
    /// @param bridge The whitelisted bridge address.
    /// @param _market The market to rebalance from address.
    /// @param _amount The amount to rebalance.
    /// @param _msg The message data.
    function sendMsg(address bridge, address _market, uint256 _amount, Msg calldata _msg) external payable;

    // ----------- VIEW METHODS ------------

    /// @notice Returns current nonce.
    /// @return currentNonce Nonce value.
    function nonce() external view returns (uint256 currentNonce);

    /// @notice Returns if a bridge implementation is whitelisted.
    /// @param bridge Bridge address.
    /// @return whitelisted True if whitelisted.
    function isBridgeWhitelisted(address bridge) external view returns (bool whitelisted);

    /// @notice Returns if a destination is whitelisted.
    /// @param dstId Destination chain ID.
    /// @return whitelisted True if whitelisted.
    function isDestinationWhitelisted(uint32 dstId) external view returns (bool whitelisted);

    /// @notice Returns if a market is whitelisted.
    /// @param market Market address.
    /// @return whitelisted True if whitelisted.
    function isMarketWhitelisted(address market) external view returns (bool whitelisted);
}
