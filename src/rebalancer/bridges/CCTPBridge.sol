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

import {IBridge} from "src/interfaces/IBridge.sol";
import {IRebalancer} from "src/interfaces/IRebalancer.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";

/// @title CCTPBridge
/// @author Malda Protocol
/// @notice Cross-chain bridge that uses Circle CCTP v2
contract CCTPBridge is BaseBridge, CCTPHelper, IBridge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------

    /// @notice The Rebalancer contract allowed to initiate bridging actions.
    address public immutable REBALANCER;

    /// @notice Maps EVM chainId -> CCTP domain id.
    mapping(uint32 chainId => uint32 cctpDomain) public chainIdToDomain;

    /// @notice Tracks whether a domain mapping exists for a given EVM chainId.
    mapping(uint32 chainId => bool isSet) public domainSet;

    // ----------- EVENTS ------------

    /// @notice Emitted when bridged funds are forwarded to a destination market.
    /// @param market The destination market that received the funds.
    /// @param amount The amount of tokens forwarded to the market.
    event Rebalanced(address indexed market, uint256 amount);

    /// @notice Emitted when a chainId -> CCTP domain mapping is updated.
    /// @param chainId The EVM chainId.
    /// @param domain The CCTP domain id.
    event DomainMappingUpdated(uint32 indexed chainId, uint32 indexed domain);

    /// @notice Emitted when a token is enabled or disabled for CCTP burns.
    /// @param token The token address.
    /// @param status True if enabled, false if disabled.
    event TokenAccepted(address indexed token, bool status);

    // ----------- ERRORS ------------

    error CCTPBridge_AddressNotValid();
    error CCTPBridge_InvalidReceiver();
    error CCTPBridge_TokenMismatch();
    error CCTPBridge_NotImplemented();
    error CCTPBridge_DomainNotSet();

    constructor(address _roles, address _tokenMessenger, address _messageTransmitter, address _rebalancer)
        BaseBridge(_roles)
        CCTPHelper(_tokenMessenger, _messageTransmitter)
    {
        require(_rebalancer != address(0), CCTPBridge_AddressNotValid());
        REBALANCER = _rebalancer;
    }

    // ----------- OWNER / CONFIG ------------

    /// @notice Sets the CCTP domain id for a given EVM chainId.
    /// @param chainId The EVM chainId to set.
    /// @param domain The corresponding CCTP domain id.
    function setDomainMapping(uint32 chainId, uint32 domain) external onlyBridgeConfigurator {
        chainIdToDomain[chainId] = domain;
        domainSet[chainId] = true;
        emit DomainMappingUpdated(chainId, domain);
    }

    /// @notice Enables or disables a token for use with CCTP burns.
    /// @param token The token address.
    /// @param allowed True to enable, false to disable.
    function setAcceptedToken(address token, bool allowed) external onlyBridgeConfigurator {
        acceptedTokens[token] = allowed;
        emit TokenAccepted(token, allowed);
    }

    // ----------- SOURCE CHAIN ------------

    /// @notice Burns tokens and creates a CCTP message for the destination chain.
    /// @param _extractedAmount Amount to burn.
    /// @param _market Destination market address (encoded into the CCTP hook payload).
    /// @param _dstChainId Destination EVM chainId.
    /// @param _token Token to burn (e.g., USDC).
    /// @param _unused1 Unused parameter kept for IBridge compatibility.
    /// @param _unused2 Unused parameter kept for IBridge compatibility.
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes calldata _unused1,
        bytes calldata _unused2
    ) external payable override onlyRebalancer {
        // silence unused param warnings without changing the interface surface
        _unused1;
        _unused2;

        require(_extractedAmount > 0, BaseBridge_AmountMismatch());

        uint32 dstDomain = chainIdToDomain[_dstChainId];
        uint32 srcDomain = chainIdToDomain[uint32(block.chainid)];
        require(domainSet[_dstChainId] && domainSet[uint32(block.chainid)], CCTPBridge_DomainNotSet());

        bytes memory payload = abi.encode(_market);

        (CCTPMessage memory cctpMsg,) =
            createAndBurn(_token, _extractedAmount, dstDomain, _toBytes32(address(this)), payload, srcDomain);

        require(cctpMsg.amount == _extractedAmount, BaseBridge_AmountMismatch());
    }

    // ----------- DESTINATION CHAIN ------------

    /// @notice Receives a CCTP message+attestation and forwards received tokens to the encoded destination market.
    /// @param cctpMessage Raw CCTP message bytes.
    /// @param attestation Circle attestation proving message validity.
    function handleCCTPMessage(bytes calldata cctpMessage, bytes calldata attestation) external nonReentrant {
        CCTPMessage memory msgData = handleDestinationMsg(cctpMessage, attestation);

        address market = abi.decode(msgData.payload, (address));
        require(IRebalancer(REBALANCER).isMarketWhitelisted(market), CCTPBridge_InvalidReceiver());

        address underlying = ImTokenMinimal(market).underlying();
        address tokenSent = address(uint160(uint256(msgData.token)));
        require(underlying == tokenSent, CCTPBridge_TokenMismatch());

        if (msgData.amount > 0) {
            IERC20(tokenSent).safeTransfer(market, msgData.amount);
            emit Rebalanced(market, msgData.amount);
        }
    }

    // ----------- VIEW ------------

    /// @notice Returns the bridge fee.
    /// @dev Not implemented for CCTP; protocol fees are handled by Circle.
    /// @param _dstChainId Unused.
    /// @param _payload Unused.
    /// @param _options Unused.
    /// @return fee Always reverts.
    function getFee(uint32 _dstChainId, bytes calldata _payload, bytes calldata _options)
        external
        pure
        override
        returns (uint256 fee)
    {
        _dstChainId;
        _payload;
        _options;

        // Fee automatically deducted
        revert CCTPBridge_NotImplemented();
    }
}
