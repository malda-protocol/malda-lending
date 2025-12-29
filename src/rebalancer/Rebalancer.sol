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
    /// @notice Roles contract used for access control
    IRoles public roles;

    /// @notice Incremental nonce used for logging messages
    uint256 public nonce;

    /// @notice Sent messages indexed by destination chain and nonce
    mapping(uint32 => mapping(uint256 => Msg)) public logs;

    /// @notice Bridge whitelist status
    mapping(address => bool) public whitelistedBridges;

    /// @notice Allowed tokens per bridge
    mapping(address => mapping(address => bool)) public allowedTokensPerBridge;

    /// @notice Destination chain whitelist status
    mapping(uint32 => bool) public whitelistedDestinations;

    /// @notice Markets allowed for rebalancing
    mapping(address => bool) public allowedList;

    /// @notice Admin address with elevated permissions
    address public admin;

    /// @notice Address used to sweep saved assets
    address public saveAddress;

    /// @notice Per-chain token maximum transfer size
    mapping(uint32 => mapping(address => uint256)) public maxTransferSizes;

    /// @notice Per-chain token minimum transfer size
    mapping(uint32 => mapping(address => uint256)) public minTransferSizes;

    /// @notice Rolling transfer info for size-window enforcement
    mapping(uint32 => mapping(address => TransferInfo)) public currentTransferSize;

    /// @notice Market whitelist status
    mapping(address => bool) public whitelistedMarkets;

    /// @notice Duration of the rolling transfer size window
    uint256 public transferTimeWindow;

    /// @notice Initializes the Rebalancer
    /// @param _roles Roles contract
    /// @param _saveAddress Address to sweep saved assets to
    /// @param _admin Admin address
    constructor(address _roles, address _saveAddress, address _admin, bytes memory initData) {
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

        if (initData.length > 0) {
            InitInfo memory info = abi.decode(initData, (InitInfo));
            
            if (info.markets.length > 0) {
                _setMarketStatus(info.markets, true);
                _setAllowList(info.markets, true);
            }

            if (info.bridges.length > 0) {
                for (uint256 i; i < info.bridges.length; ++i) {
                    _setWhitelistedBridgeStatus(info.bridges[i], true);
                }
            }

            if (info.destinations.length > 0) {
                for (uint256 i; i < info.destinations.length; ++i) {
                    _setWhitelistedDestination(info.destinations[i], true);
                }
            }

            if (info.bridgeTokens.length > 0) {
                for (uint256 i; i < info.bridgeTokens.length; ++i) {
                    _setAllowedTokens(info.bridgeTokens[i].bridge, info.bridgeTokens[i].tokens, true);
                }
            }
        }
    }

    // ----------- OWNER METHODS ------------
    /// @notice Initialize firewall
    /// @param _firewall Firewall address
    function initFirewall(address _firewall) external {
        // Requirements: the caller is the admin
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();

        // Effects: initialize firewall
        _initHypernativeFirewall(_firewall, admin);
    }   

    /// @notice Set admin
    /// @param _account Admin address
    function setAdmin(address _account) external { 
        // Requirements: the caller is the admin
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();

        // Effects: set admin
        admin = _account;

        // Events: emit the new admin event
        emit NewAdmin(_account);
    }

    /// @notice Set save address
    /// @param _save Save address
    function setSaveAddress(address _save) external {
        // Requirements: the caller is the admin
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();

        // Effects: set save address
        saveAddress = _save;
    }

    /// @notice Set allowed tokens for a bridge
    /// @param bridge Bridge address
    /// @param tokens Token list to allow/disallow
    /// @param status Allowance status
    function setAllowedTokens(address bridge, address[] memory tokens, bool status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        // Effects: set allowed tokens
        _setAllowedTokens(bridge, tokens, status);
    }

    /// @notice Batch whitelist/unwhitelist markets
    /// @param list Market addresses
    /// @param status Whitelist status
    function setMarketStatus(address[] memory list, bool status) public onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        // Effects: set market status
        _setMarketStatus(list, status);
    }

    /// @notice Batch set allow-list status for markets
    /// @param list Market addresses
    /// @param status Allow list status
    function setAllowList(address[] memory list, bool status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        // Effects: set allow list
        _setAllowList(list, status);
    }

    /// @notice Set whitelist status for a bridge
    /// @param _bridge Bridge address
    /// @param _status Whitelist status
    function setWhitelistedBridgeStatus(address _bridge, bool _status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        // Effects: set whitelisted bridge
        _setWhitelistedBridgeStatus(_bridge, _status);
    }

    /// @notice Set whitelist status for a destination chain
    /// @param _dstId Destination chain id
    /// @param _status Whitelist status
    function setWhitelistedDestination(uint32 _dstId, bool _status) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        // Effects: set whitelisted destination
        _setWhitelistedDestination(_dstId, _status);
    }

    /// @notice Sweep native ETH to the configured save address
    function saveEth() external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

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
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();

        address _underlying = ImTokenMinimal(market).underlying();
        require(_underlying == token, Rebalancer_RequestNotValid());
        
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(market, amount);
        emit TokensSaved(token, market, amount);
    }

    function setMinTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized()
        ;
        // Effects: set the minimum transfer size
        minTransferSizes[_dstChainId][_token] = _limit;

        // Events: emit the minimum transfer size updated event
        emit MinTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    function setMaxTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApprovedAllowEOA {
        // Requirements: the caller is the bridge configurator
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        // Effects: set the maximum transfer size
        maxTransferSizes[_dstChainId][_token] = _limit;

        // Events: emit the maximum transfer size updated event
        emit MaxTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    // ----------- VIEW METHODS ------------
     /**
     * @inheritdoc IRebalancer
     */
    function isMarketWhitelisted(address market) external view returns (bool) {
        return whitelistedMarkets[market];
    }

    /**
     * @inheritdoc IRebalancer
     */
    function isBridgeWhitelisted(address bridge) external view returns (bool) {
        return whitelistedBridges[bridge];
    }

    /**
     * @inheritdoc IRebalancer
     */
    function isDestinationWhitelisted(uint32 dstId) external view returns (bool) {
        return whitelistedDestinations[dstId];
    }

    // ----------- EXTERNAL METHODS ------------
    function firewallRegister(address _account) public override(HypernativeFirewallProtected) {
        super.firewallRegister(_account);
    }
    
    /**
     * @inheritdoc IRebalancer
     */
    function sendMsg(address _bridge, address _market, uint256 _amount, Msg calldata _msg) external payable onlyFirewallApprovedAllowEOA {
        _sendMsgPreChecks(_bridge, _market, _amount, _msg);

        // max transfer size checks
        TransferInfo storage transferInfo = currentTransferSize[_msg.dstChainId][_msg.token];
        uint256 transferSizeDeadline = transferInfo.timestamp + transferTimeWindow;

        if (transferSizeDeadline < block.timestamp) {
            // reset the window
            transferInfo.size = _amount;
            transferInfo.timestamp = block.timestamp;
        } else {
            transferInfo.size += _amount;
        }

        uint256 _maxTransferSize = maxTransferSizes[_msg.dstChainId][_msg.token];
        if (_maxTransferSize > 0) {
            require(transferInfo.size <= _maxTransferSize, Rebalancer_TransferSizeExcedeed());
        }

        // retrieve amounts (make sure to check min and max for that bridge)
        require(allowedList[_market], Rebalancer_MarketNotValid());
        IRebalanceMarket(_market).extractForRebalancing(_amount);

        // log
        unchecked {
            ++nonce;
        }
        logs[_msg.dstChainId][nonce] = _msg;

        // approve and trigger send
        SafeApprove.safeApprove(_msg.token, _bridge, _amount);
        IBridge(_bridge).sendMsg{value: msg.value}(
            _amount, _market, _msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData
        );

        emit MsgSent(_bridge, _msg.dstChainId, _msg.token, _msg.message, _msg.bridgeData);
    }

    // ----------- INTERNAL METHODS ------------
    function _sendMsgPreChecks(address _bridge, address _market, uint256 _amount, Msg calldata _msg) internal {
         // checks
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER_EOA())) revert Rebalancer_NotAuthorized();
        require(whitelistedBridges[_bridge], Rebalancer_BridgeNotWhitelisted());
        require(whitelistedDestinations[_msg.dstChainId], Rebalancer_DestinationNotWhitelisted());
        address _underlying = ImTokenMinimal(_market).underlying();
        require(_underlying == _msg.token, Rebalancer_RequestNotValid());
        require(allowedTokensPerBridge[_bridge][_underlying], Rebalancer_UnderlyingNotAllowedForBridge());

        // min transfer size check
        require(_amount > minTransferSizes[_msg.dstChainId][_msg.token], Rebalancer_TransferSizeMinNotMet());
    }

     function _setMarketStatus(address[] memory list, bool status) internal {
        uint256 len = list.length;
        for (uint256 i; i < len; i++) {
            whitelistedMarkets[list[i]] = status;
        }
        emit MarketListUpdated(list, status);
    }

    function _setAllowList(address[] memory list, bool status) internal {
        uint256 len = list.length;
        for (uint256 i; i < len; i++) {
            allowedList[list[i]] = status;
        }
        emit AllowedListUpdated(list, status);
    }

    function _setWhitelistedBridgeStatus(address _bridge, bool _status) internal {
        require(_bridge != address(0), Rebalancer_AddressNotValid());
        whitelistedBridges[_bridge] = _status;
        emit BridgeWhitelistedStatusUpdated(_bridge, _status);
    }

    function _setWhitelistedDestination(uint32 _dstId, bool _status) internal {
        emit DestinationWhitelistedStatusUpdated(_dstId, _status);
        whitelistedDestinations[_dstId] = _status;
    }

    function _setAllowedTokens(address bridge, address[] memory tokens, bool status) internal {
        uint256 len = tokens.length;
        for (uint256 i; i < len; i++) {
            // Effects: set the allowed tokens for the bridge
            allowedTokensPerBridge[bridge][tokens[i]] = status;
        }
        // Events: emit the allowed tokens updated event
        emit AllowedTokensUpdated(bridge, status, tokens);
    }
}