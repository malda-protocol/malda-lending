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

import {IRoles} from "src/interfaces/IRoles.sol";
import {IBridge} from "src/interfaces/IBridge.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IRebalancer, IRebalanceMarket} from "src/interfaces/IRebalancer.sol";
import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";

/// @title Cross-chain rebalancer
/// @author Malda Protocol
/// @notice Manages bridge interactions and transfer size limits for cross-chain rebalancing.
contract Rebalancer is IRebalancer, HypernativeFirewallProtected {
    using SafeERC20 for IERC20;

    struct TransferInfo {
        uint256 size;
        uint256 timestamp;
    }

    struct InitInfo {
        BridgeTokens[] bridgeTokens;
        address[] markets;
        address[] bridges;
        uint32[] destinations;
    }

    struct BridgeTokens {
        address bridge;
        address[] tokens;
    }

    // ----------- STORAGE ------------

    /// @notice Roles contract used for access control.
    IRoles public roles;

    /// @notice Incremental nonce used for logging messages.
    uint256 public nonce;

    /// @notice Sent messages indexed by destination chain and nonce.
    mapping(uint32 dstChainId => mapping(uint256 msgNonce => Msg message)) public logs;

    /// @notice Bridge whitelist status.
    mapping(address bridge => bool status) public whitelistedBridges;

    /// @notice Allowed tokens per bridge.
    mapping(address bridge => mapping(address token => bool status)) public allowedTokensPerBridge;

    /// @notice Destination chain whitelist status.
    mapping(uint32 dstChainId => bool status) public whitelistedDestinations;

    /// @notice Markets allowed for rebalancing.
    mapping(address market => bool status) public allowedList;

    /// @notice Admin address with elevated permissions.
    address public admin;

    /// @notice Address used to sweep saved assets.
    address public saveAddress;

    /// @notice Per-chain token maximum transfer size.
    mapping(uint32 dstChainId => mapping(address token => uint256 limit)) public maxTransferSizes;

    /// @notice Per-chain token minimum transfer size.
    mapping(uint32 dstChainId => mapping(address token => uint256 limit)) public minTransferSizes;

    /// @notice Rolling transfer info for size-window enforcement.
    mapping(uint32 dstChainId => mapping(address token => TransferInfo info)) public currentTransferSize;

    /// @notice Market whitelist status.
    mapping(address market => bool status) public whitelistedMarkets;

    /// @notice Duration of the rolling transfer size window.
    uint256 public transferTimeWindow;

    /// @notice Initializes the Rebalancer.
    /// @param _roles Roles contract.
    /// @param _saveAddress Address to sweep saved assets to.
    /// @param _admin Admin address.
    /// @param initData Optional initialization data (InitInfo ABI-encoded).
    constructor(address _roles, address _saveAddress, address _admin, bytes memory initData) {
        require(_roles != address(0), Rebalancer_AddressNotValid());
        require(_saveAddress != address(0), Rebalancer_AddressNotValid());
        require(_admin != address(0), Rebalancer_AddressNotValid());

        roles = IRoles(_roles);
        transferTimeWindow = 86400;
        saveAddress = _saveAddress;
        admin = _admin;

        _initFromData(initData);
    }

    // ----------- OWNER METHODS ------------

    /// @notice Initialize firewall.
    /// @param _firewall Firewall address.
    function initFirewall(address _firewall) external {
        require(msg.sender == admin, Rebalancer_NotAuthorized());
        _initHypernativeFirewall(_firewall, admin);
    }

    /// @notice Set admin.
    /// @param _account Admin address.
    function setAdmin(address _account) external {
        // Requirements: the account is not zero address
        require(_account != address(0), Rebalancer_AddressNotValid());

        // Requirements: the caller is the admin
        require(msg.sender == admin, Rebalancer_NotAuthorized());

        // Effects: set the admin
        admin = _account;

        // Events: emit the new admin event
        emit NewAdmin(_account);
    }

    /// @notice Set save address.
    /// @param _save Save address.
    function setSaveAddress(address _save) external {
        // Requirements: the save address is not zero address
        require(_save != address(0), Rebalancer_AddressNotValid());

        // Requirements: the caller is the admin
        require(msg.sender == admin, Rebalancer_NotAuthorized());

        // Effects: set the save address
        saveAddress = _save;

        // Events: emit the new save address event
        emit SaveAddressUpdated(_save);
    }

    /// @notice Set allowed tokens for a bridge.
    /// @param bridge Bridge address.
    /// @param tokens Token list to allow/disallow.
    /// @param status Allowance status.
    function setAllowedTokens(address bridge, address[] calldata tokens, bool status)
        external
        onlyFirewallApprovedAllowEOA
    {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the allowed tokens
        _setAllowedTokens(bridge, tokens, status);
    }

    /// @notice Batch whitelist/unwhitelist markets.
    /// @param list Market addresses.
    /// @param status Whitelist status.
    function setMarketStatus(address[] calldata list, bool status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the market status
        _setMarketStatus(list, status);
    }

    /// @notice Batch set allow-list status for markets.
    /// @param list Market addresses.
    /// @param status Allow list status.
    function setAllowList(address[] calldata list, bool status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the allow list
        _setAllowList(list, status);
    }

    /// @notice Set whitelist status for a bridge.
    /// @param _bridge Bridge address.
    /// @param _status Whitelist status.
    function setWhitelistedBridgeStatus(address _bridge, bool _status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the whitelisted bridge status
        _setWhitelistedBridgeStatus(_bridge, _status);
    }

    /// @notice Set whitelist status for a destination chain.
    /// @param _dstId Destination chain id.
    /// @param _status Whitelist status.
    function setWhitelistedDestination(uint32 _dstId, bool _status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the whitelisted destination
        _setWhitelistedDestination(_dstId, _status);
    }

    /// @notice Sweep native ETH to the configured save address.
    function saveEth() external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        uint256 amount = address(this).balance;

        // Interactions: sweep the native ETH to the save address
        // slither-disable-next-line arbitrary-send-eth
        (bool success,) = saveAddress.call{value: amount}("");
        require(success, Rebalancer_RequestNotValid());

        // Events: emit the ETH saved event
        emit EthSaved(amount);
    }

    /// @notice Sweep stray tokens to the given market.
    /// @param token Token address to sweep.
    /// @param market Market to receive tokens.
    function saveTokens(address token, address market) external {
        // Requirements: the caller is the admin
        require(msg.sender == admin, Rebalancer_NotAuthorized());

        // Requirements: the market is valid
        address _underlying = ImTokenMinimal(market).underlying();
        // Requirements: the underlying token is the same as the token
        require(_underlying == token, Rebalancer_RequestNotValid());

        // Interactions: sweep the tokens to the market
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(market, amount);

        // Events: emit the tokens saved event
        emit TokensSaved(token, market, amount);
    }

    /// @notice Sets the minimum transfer size for a given destination and token.
    /// @param _dstChainId Destination chain id.
    /// @param _token Token address.
    /// @param _limit Minimum transfer size.
    function setMinTransferSize(uint32 _dstChainId, address _token, uint256 _limit)
        external
        onlyFirewallApprovedAllowEOA
    {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the minimum transfer size
        minTransferSizes[_dstChainId][_token] = _limit;

        // Events: emit the minimum transfer size updated event
        emit MinTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    /// @notice Sets the maximum transfer size for a given destination and token.
    /// @param _dstChainId Destination chain id.
    /// @param _token Token address.
    /// @param _limit Maximum transfer size.
    function setMaxTransferSize(uint32 _dstChainId, address _token, uint256 _limit)
        external
        onlyFirewallApprovedAllowEOA
    {
        // Requirements: the caller is allowed for guardian bridge
        require(roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE()), Rebalancer_NotAuthorized());

        // Effects: set the maximum transfer size
        maxTransferSizes[_dstChainId][_token] = _limit;

        // Events: emit the maximum transfer size updated event
        emit MaxTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    // ----------- EXTERNAL METHODS ------------

    /// @inheritdoc IRebalancer
    function sendMsg(address _bridge, address _market, uint256 _amount, Msg calldata _msg)
        external
        payable
        onlyFirewallApprovedAllowEOA
    {
        // Requirements: check the pre-conditions
        _sendMsgPreChecks(_bridge, _market, _amount, _msg);

        // Effects: update the transfer window and check the maximum transfer size
        _updateTransferWindowAndCheckMax(_amount, _msg.dstChainId, _msg.token);

        // Requirements: the market is allowed
        require(allowedList[_market], Rebalancer_MarketNotValid());

        // Interactions: extract the tokens for rebalancing
        IRebalanceMarket(_market).extractForRebalancing(_amount);

        // Effects: increment the nonce
        unchecked {
            ++nonce;
        }

        // Effects: log the message
        logs[_msg.dstChainId][nonce] = _msg;

        // Interactions: approve the tokens
        SafeApprove.safeApprove(_msg.token, _bridge, _amount);

        // Interactions: send the message
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

    /// @notice Registers an account with the firewall.
    /// @param _account Account to register.
    function firewallRegister(address _account) public override(HypernativeFirewallProtected) {
        super.firewallRegister(_account);
    }

    // ----------- INTERNAL METHODS ------------

    /// @notice Initializes the Rebalancer from initialization data.
    /// @param initData Initialization data.
    function _initFromData(bytes memory initData) internal {
        if (initData.length == 0) return;

        InitInfo memory info = abi.decode(initData, (InitInfo));

        if (info.markets.length > 0) {
            _initMarkets(info.markets);
        }

        if (info.bridges.length > 0) {
            _initBridges(info.bridges);
        }

        if (info.destinations.length > 0) {
            _initDestinations(info.destinations);
        }

        if (info.bridgeTokens.length > 0) {
            _initBridgeTokens(info.bridgeTokens);
        }
    }

    /// @notice Initializes the markets.
    /// @param markets Markets to initialize.
    function _initMarkets(address[] memory markets) internal {
        _setMarketStatus(markets, true);
        _setAllowList(markets, true);
    }

    /// @notice Initializes the bridges.
    /// @param bridges Bridges to initialize.
    function _initBridges(address[] memory bridges) internal {
        uint256 len = bridges.length;
        for (uint256 i; i < len; ++i) {
            _setWhitelistedBridgeStatus(bridges[i], true);
        }
    }

    /// @notice Initializes the destinations.
    /// @param destinations Destinations to initialize.
    function _initDestinations(uint32[] memory destinations) internal {
        uint256 len = destinations.length;
        for (uint256 i; i < len; ++i) {
            _setWhitelistedDestination(destinations[i], true);
        }
    }

    /// @notice Initializes the bridge tokens.
    /// @param bridgeTokens Bridge tokens to initialize.
    function _initBridgeTokens(BridgeTokens[] memory bridgeTokens) internal {
        uint256 len = bridgeTokens.length;
        for (uint256 i; i < len; ++i) {
            _setAllowedTokens(bridgeTokens[i].bridge, bridgeTokens[i].tokens, true);
        }
    }

    /// @notice Checks the pre-conditions for sending a message.
    /// @param _bridge Bridge address.
    /// @param _market Market address.
    /// @param _amount Amount to send.
    /// @param _msg Message data.
    function _sendMsgPreChecks(address _bridge, address _market, uint256 _amount, Msg calldata _msg) internal {
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER_EOA())) revert Rebalancer_NotAuthorized();
        require(whitelistedBridges[_bridge], Rebalancer_BridgeNotWhitelisted());
        require(whitelistedDestinations[_msg.dstChainId], Rebalancer_DestinationNotWhitelisted());

        address _underlying = ImTokenMinimal(_market).underlying();
        require(_underlying == _msg.token, Rebalancer_RequestNotValid());
        require(allowedTokensPerBridge[_bridge][_underlying], Rebalancer_UnderlyingNotAllowedForBridge());

        require(_amount > minTransferSizes[_msg.dstChainId][_msg.token], Rebalancer_TransferSizeMinNotMet());
    }

    /// @notice Updates the transfer window and checks the maximum transfer size.
    /// @param amount Amount to send.
    /// @param dstChainId Destination chain id.
    /// @param token Token address.
    function _updateTransferWindowAndCheckMax(uint256 amount, uint32 dstChainId, address token) internal {
        TransferInfo storage transferInfo = currentTransferSize[dstChainId][token];
        uint256 deadline = transferInfo.timestamp + transferTimeWindow;

        if (deadline < block.timestamp) {
            transferInfo.size = amount;
            transferInfo.timestamp = block.timestamp;
        } else {
            transferInfo.size += amount;
        }

        uint256 maxSize = maxTransferSizes[dstChainId][token];
        if (maxSize == 0) return;

        require(transferInfo.size <= maxSize, Rebalancer_TransferSizeExcedeed());
    }

    /// @notice Sets the market status.
    /// @param list Market addresses.
    /// @param status Market status.
    function _setMarketStatus(address[] memory list, bool status) internal {
        uint256 len = list.length;
        for (uint256 i; i < len; i++) {
            whitelistedMarkets[list[i]] = status;
        }
        emit MarketListUpdated(list, status);
    }

    /// @notice Sets the allow list.
    /// @param list Market addresses.
    /// @param status Allow list status.
    function _setAllowList(address[] memory list, bool status) internal {
        uint256 len = list.length;
        for (uint256 i; i < len; i++) {
            allowedList[list[i]] = status;
        }
        emit AllowedListUpdated(list, status);
    }

    /// @notice Sets the whitelisted bridge status.
    /// @param _bridge Bridge address.
    /// @param _status Whitelisted bridge status.
    function _setWhitelistedBridgeStatus(address _bridge, bool _status) internal {
        require(_bridge != address(0), Rebalancer_AddressNotValid());
        whitelistedBridges[_bridge] = _status;
        emit BridgeWhitelistedStatusUpdated(_bridge, _status);
    }

    /// @notice Sets the whitelisted destination.
    /// @param _dstId Destination chain id.
    /// @param _status Whitelisted destination status.
    function _setWhitelistedDestination(uint32 _dstId, bool _status) internal {
        emit DestinationWhitelistedStatusUpdated(_dstId, _status);
        whitelistedDestinations[_dstId] = _status;
    }

    /// @notice Sets the allowed tokens.
    /// @param bridge Bridge address.
    /// @param tokens Token addresses.
    /// @param status Allowed tokens status.
    function _setAllowedTokens(address bridge, address[] memory tokens, bool status) internal {
        uint256 len = tokens.length;
        for (uint256 i; i < len; i++) {
            allowedTokensPerBridge[bridge][tokens[i]] = status;
        }
        emit AllowedTokensUpdated(bridge, status, tokens);
    }
}
