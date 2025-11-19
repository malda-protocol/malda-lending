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

contract Rebalancer is IRebalancer, HypernativeFirewallProtected {
    using SafeERC20 for IERC20;
    
    // ----------- STORAGE ------------
    IRoles public roles;
    uint256 public nonce;
    mapping(uint32 => mapping(uint256 => Msg)) public logs;
    mapping(address => bool) public whitelistedBridges;
    mapping(address => mapping(address => bool)) public allowedTokensPerBridge;
    mapping(uint32 => bool) public whitelistedDestinations;
    mapping(address => bool) public allowedList;
    address public admin;

    address public saveAddress;

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

    mapping(uint32 => mapping(address => uint256)) public maxTransferSizes;
    mapping(uint32 => mapping(address => uint256)) public minTransferSizes;
    mapping(uint32 => mapping(address => TransferInfo)) public currentTransferSize;
    mapping(address => bool) public whitelistedMarkets;
    uint256 public transferTimeWindow;

    constructor(address _roles, address _saveAddress, address _admin, bytes memory initData) {
        require(_roles != address(0), Rebalancer_AddressNotValid());
        require(_saveAddress != address(0), Rebalancer_AddressNotValid());
        require(_admin != address(0), Rebalancer_AddressNotValid());
        
        roles = IRoles(_roles);
        transferTimeWindow = 86400;
        saveAddress = _saveAddress;
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
    function initFirewall(address _firewall) external {
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();

        _initHypernativeFirewall(_firewall, admin);
    }   

    function setAdmin(address _account) external { 
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();

        admin = _account;
        emit NewAdmin(_account);
    }

    function setSaveAddress(address _save) external {
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();
        saveAddress = _save;
    }

    function setAllowedTokens(address bridge, address[] memory tokens, bool status) external onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        _setAllowedTokens(bridge, tokens, status);
    }

    function setMarketStatus(address[] memory list, bool status) public onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        _setMarketStatus(list, status);
    }

    function setAllowList(address[] memory list, bool status) external onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        _setAllowList(list, status);
    }

    function setWhitelistedBridgeStatus(address _bridge, bool _status) external onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        _setWhitelistedBridgeStatus(_bridge, _status);
    }

    function setWhitelistedDestination(uint32 _dstId, bool _status) external onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        _setWhitelistedDestination(_dstId, _status);
    }

    function saveEth() external onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();

        uint256 amount = address(this).balance;
        // no need to check return value
        (bool success,) = saveAddress.call{value: amount}("");
        require(success, Rebalancer_RequestNotValid());
        emit EthSaved(amount);
    }

    function saveTokens(address token, address market) external {
        if (msg.sender != admin) revert Rebalancer_NotAuthorized();

        address _underlying = ImTokenMinimal(market).underlying();
        require(_underlying == token, Rebalancer_RequestNotValid());
        
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(market, amount);
        emit TokensSaved(token, market, amount);
    }

    function setMinTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        minTransferSizes[_dstChainId][_token] = _limit;
        emit MinTransferSizeUpdated(_dstChainId, _token, _limit);
    }

    function setMaxTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApprovedAllowEOA {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert Rebalancer_NotAuthorized();
        maxTransferSizes[_dstChainId][_token] = _limit;
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
            allowedTokensPerBridge[bridge][tokens[i]] = status;
        }
        emit AllowedTokensUpdated(bridge, status, tokens);
    }
}
