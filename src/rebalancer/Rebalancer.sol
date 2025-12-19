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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {IBridge} from "src/interfaces/IBridge.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IRebalancer, IRebalanceMarket} from "src/interfaces/IRebalancer.sol";
import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";

/// @title Cross-chain rebalancer
/// @author Malda Protocol
/// @notice Manages bridge interactions and transfer size limits for cross-chain rebalancing.
contract Rebalancer is IRebalancer, HypernativeFirewallProtected, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct TransferInfo {
        uint256 size;
        uint256 timestamp;
    }

    // ----------- STORAGE ------------
    /// @notice Roles contract used for access control
    IRoles public roles;

    /// @notice Incremental nonce used for logging messages
    uint256 public nonce;

    /// @notice Sent messages indexed by destination chain and nonce
    mapping(uint32 chainId => mapping(uint256 nonce => Msg message)) public logs;

    /// @notice Bridge whitelist status
    mapping(address bridge => bool whitelisted) public whitelistedBridges;

    /// @notice Allowed tokens per bridge
    mapping(address bridge => mapping(address token => bool allowed)) public allowedTokensPerBridge;

    /// @notice Destination chain whitelist status
    mapping(uint32 dstChainId => bool whitelisted) public whitelistedDestinations;

    /// @notice Markets allowed for rebalancing
    mapping(address market => bool allowed) public allowedList;

    /// @notice Admin address with elevated permissions
    address public admin;

    /// @notice Address used to sweep saved assets
    address public saveAddress;

    /// @notice Per-chain token maximum transfer size
    mapping(uint32 dstChainId => mapping(address token => uint256 maxSize)) public maxTransferSizes;

    /// @notice Per-chain token minimum transfer size
    mapping(uint32 dstChainId => mapping(address token => uint256 minSize)) public minTransferSizes;

    /// @notice Rolling transfer info for size-window enforcement
    mapping(uint32 dstChainId => mapping(address token => TransferInfo transferInfo)) public currentTransferSize;

    /// @notice Market whitelist status
    mapping(address market => bool whitelisted) public whitelistedMarkets;

    /// @notice Duration of the rolling transfer size window
    uint256 public transferTimeWindow;

    /// @notice Initializes the Rebalancer
    /// @param _roles Roles contract
    /// @param _saveAddress Address to sweep saved assets to
    /// @param _admin Admin address
    constructor(address _roles, address _saveAddress, address _admin) {
        // Requirements: the roles address is not zero
        require(_roles != address(0), Rebalancer_AddressNotValid());

        // Requirements: the save address is not zero
        require(_saveAddress != address(0), Rebalancer_AddressNotValid());

        // Requirements: the admin address is not zero
        require(_admin != address(0), Rebalancer_AddressNotValid());

        // Effects: set the roles contract
        roles = IRoles(_roles);

        // Effects: set the transfer time window to 1 day
        transferTimeWindow = 86400;

        // Effects: set the save address
        saveAddress = _saveAddress;

        // Effects: set the admin address
        admin = _admin;
    }

    // ----------- OWNER METHODS ------------

    /// @notice Set allowed tokens for a bridge
    /// @param bridge Bridge address
    /// @param tokens Token list to allow/disallow
    /// @param status Allowance status
    function setAllowedTokens(address bridge, address[] calldata tokens, bool status) external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        uint256 len = tokens.length;
        for (uint256 i; i < len; i++) {
            // Effects: set the allowed tokens for the bridge
            allowedTokensPerBridge[bridge][tokens[i]] = status;
        }

        // Events: emit the allowed tokens updated event
        emit AllowedTokensUpdated(bridge, status, tokens);
    }

    /// @notice Batch whitelist/unwhitelist markets
    /// @param list Market addresses
    /// @param status Whitelist status
    function setMarketStatus(address[] calldata list, bool status) external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        uint256 len = list.length;
        for (uint256 i; i < len; i++) {
            // Effects: set the market whitelist status
            whitelistedMarkets[list[i]] = status;
        }

        // Events: emit the market list updated event
        emit MarketListUpdated(list, status);
    }

    /// @notice Batch set allow-list status for markets
    /// @param list Market addresses
    /// @param status Allow list status
    function setAllowList(address[] calldata list, bool status) external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        uint256 len = list.length;
        for (uint256 i; i < len; i++) {
            // Effects: set the allow list status
            allowedList[list[i]] = status;
        }

        // Events: emit the allowed list updated event
        emit AllowedListUpdated(list, status);
    }

    /// @notice Set whitelist status for a bridge
    /// @param _bridge Bridge address
    /// @param status_ Whitelist status
    function setWhitelistedBridgeStatus(address _bridge, bool status_) external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Requirements: the bridge address is not zero
        require(_bridge != address(0), Rebalancer_AddressNotValid());

        // Effects: set the bridge whitelist status
        whitelistedBridges[_bridge] = status_;

        // Events: emit the bridge whitelist status updated event
        emit BridgeWhitelistedStatusUpdated(_bridge, status_);
    }

    /// @notice Set whitelist status for a destination chain
    /// @param _dstId Destination chain id
    /// @param status_ Whitelist status
    function setWhitelistedDestination(uint32 _dstId, bool status_) external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the destination whitelist status
        whitelistedDestinations[_dstId] = status_;

        // Events: emit the destination whitelist status updated event
        emit DestinationWhitelistedStatusUpdated(_dstId, status_);
    }

    /// @notice Sweep native ETH to the configured save address
    function saveEth() external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        uint256 amount = address(this).balance;

        // Interactions: sweep the native ETH to the save address
        // slither-disable-next-line arbitrary-send-eth
        (bool success,) = saveAddress.call{value: amount}("");
        require(success, Rebalancer_RequestNotValid());

        // Events: emit the ETH saved event
        emit EthSaved(amount);
    }

    /// @notice Sweep stray tokens to the given market
    /// @param token Token address to sweep
    /// @param market Market to receive tokens
    function saveTokens(address token, address market) external {
        // Requirements: the caller is the admin
        require(msg.sender == admin, Rebalancer_NotAuthorized());

        address _underlying = ImTokenMinimal(market).underlying();
        // Requirements: the underlying market token matches the given token
        require(_underlying == token, Rebalancer_RequestNotValid());

        uint256 amount = IERC20(token).balanceOf(address(this));
        // Interactions: transfer the tokens to the market
        IERC20(token).safeTransfer(market, amount);

        // Events: emit the tokens saved event
        emit TokensSaved(token, market, amount);
    }

    /// @notice Set minimum transfer size for a destination/token
    /// @param _dstChainId Destination chain id
    /// @param _token Token address
    /// @param _limit Minimum size
    function setMinTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the minimum transfer size
        minTransferSizes[_dstChainId][_token] = _limit;

        // Events: emit the minimum transfer size updated event
        emit MinTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    /// @notice Set maximum transfer size for a destination/token
    /// @param _dstChainId Destination chain id
    /// @param _token Token address
    /// @param _limit Maximum size
    function setMaxTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApproved {
        // Requirements: the caller is the bridge configurator
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the maximum transfer size
        maxTransferSizes[_dstChainId][_token] = _limit;

        // Events: emit the maximum transfer size updated event
        emit MaxTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    /// @inheritdoc IRebalancer
    function sendMsg(address _bridge, address _market, uint256 _amount, Msg calldata _msg)
        external
        payable
        onlyFirewallApproved
        nonReentrant
    {
        // Requirements: the caller is the rebalancer
        require(roles.isAllowedFor(msg.sender, roles.REBALANCER_EOA()), Rebalancer_NotAuthorized());

        // Requirements: the bridge is whitelisted
        require(whitelistedBridges[_bridge], Rebalancer_BridgeNotWhitelisted());

        // Requirements: the destination chain is whitelisted
        require(whitelistedDestinations[_msg.dstChainId], Rebalancer_DestinationNotWhitelisted());

        address _underlying = ImTokenMinimal(_market).underlying();
        // Requirements: the underlying token matches the token
        require(_underlying == _msg.token, Rebalancer_RequestNotValid());

        // Requirements: the underlying token is allowed for the bridge
        require(allowedTokensPerBridge[_bridge][_underlying], Rebalancer_UnderlyingNotAllowedForBridge());

        // Requirements: the amount is greater than the minimum transfer size
        require(_amount > minTransferSizes[_msg.dstChainId][_msg.token], Rebalancer_TransferSizeMinNotMet());

        // Get the current transfer size information for the destination chain and token
        TransferInfo storage transferInfo = currentTransferSize[_msg.dstChainId][_msg.token];
        uint256 transferSizeDeadline = transferInfo.timestamp + transferTimeWindow;

        if (transferSizeDeadline < block.timestamp) {
            // Effects: reset the transfer size window
            transferInfo.size = _amount;
            transferInfo.timestamp = block.timestamp;
        } else {
            // Effects: add the amount to the transfer size
            transferInfo.size += _amount;
        }

        uint256 _maxTransferSize = maxTransferSizes[_msg.dstChainId][_msg.token];
        // Requirements: the transfer size is less than the maximum transfer size
        if (_maxTransferSize > 0) {
            require(transferInfo.size <= _maxTransferSize, Rebalancer_TransferSizeExcedeed());
        }

        // Requirements: the market is allowed
        require(allowedList[_market], Rebalancer_MarketNotValid());

        // Effects: increment the nonce
        unchecked {
            ++nonce;
        }

        // Effects: log the message
        logs[_msg.dstChainId][nonce] = _msg;

        // Interactions: extract the amount for rebalancing
        IRebalanceMarket(_market).extractForRebalancing(_amount);

        // Interactions: approve the tokens to the bridge
        SafeApprove.safeApprove(_msg.token, _bridge, _amount);

        // Interactions: trigger the send message
        IBridge(_bridge).sendMsg{value: msg.value}(
            _amount, _market, _msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData
        );

        // Events: emit the message sent event
        emit MsgSent(_bridge, _msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData);
    }

    // ----------- VIEW METHODS ------------
    /// @inheritdoc IRebalancer
    function isMarketWhitelisted(address market) external view returns (bool) {
        return whitelistedMarkets[market];
    }

    /// @inheritdoc IRebalancer
    function isBridgeWhitelisted(address bridge) external view returns (bool) {
        return whitelistedBridges[bridge];
    }

    /// @inheritdoc IRebalancer
    function isDestinationWhitelisted(uint32 dstId) external view returns (bool) {
        return whitelistedDestinations[dstId];
    }

    // ----------- EXTERNAL METHODS ------------
    /// @notice Registers an account with the firewall
    /// @param _account Account to register
    function firewallRegister(address _account) public override(HypernativeFirewallProtected) {
        super.firewallRegister(_account);
    }
}
