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

contract CCTPBridge is BaseBridge, CCTPHelper, IBridge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    address public immutable rebalancer;
    mapping(uint32 => uint32) public chainIdToDomain; //chain to cctp domain

    // ----------- EVENTS ------------
    event Rebalanced(address indexed market, uint256 amount);
    event DomainMappingUpdated(
        uint32 indexed chainId,
        uint32 indexed domain
    );
    event TokenAccepted(address indexed token, bool status);

    // ----------- ERRORS ------------
    error CCTPBridge_AddressNotValid();
    error CCTPBridge_InvalidReceiver();
    error CCTPBridge_TokenMismatch();
    error CCTPBridge_NotImplemented();
    error CCTPBridge_DomainNotSet();
    error CCTPBridge_LocalDomainNotSet();

    constructor(
        address _roles,
        address _tokenMessenger,
        address _messageTransmitter,
        address _rebalancer
    )
        BaseBridge(_roles)
        CCTPHelper(_tokenMessenger, _messageTransmitter)
    {
        if (_rebalancer == address(0)) revert CCTPBridge_AddressNotValid();
        rebalancer = _rebalancer;
    }

    // ----------- OWNER / CONFIG ------------
    function setDomainMapping(uint32 chainId, uint32 domain)
        external
        onlyBridgeConfigurator
    {
        chainIdToDomain[chainId] = domain;
        emit DomainMappingUpdated(chainId, domain);
    }

    function setAcceptedToken(address token, bool allowed)
        external
        onlyBridgeConfigurator
    {
        acceptedTokens[token] = allowed;
        emit TokenAccepted(token, allowed);
    }

    // ----------- VIEW ------------
    function getFee(
        uint32,
        bytes memory,
        bytes memory
    ) external pure override returns (uint256) {
        revert CCTPBridge_NotImplemented();
    }

    function getDomainFromChainId(uint32 chainId)
        public
        view
        returns (uint32)
    {
        uint32 domain = chainIdToDomain[chainId];
        return domain;
    }

    function localDomain() public view returns (uint32) {
        uint32 domain = chainIdToDomain[uint32(block.chainid)];
        return domain;
    }

    // ----------- SOURCE CHAIN ------------
    function sendMsg(
        uint256 _extractedAmount,
        address _market,
        uint32 _dstChainId,
        address _token,
        bytes memory,
        bytes memory
    ) external payable override onlyRebalancer {
        require(_extractedAmount > 0, BaseBridge_AmountMismatch());

        uint32 dstDomain = getDomainFromChainId(_dstChainId);
        uint32 srcDomain = localDomain();

        bytes memory payload = abi.encode(_market);

        (CCTPMessage memory cctpMsg, ) = createAndBurn(
            _token,
            _extractedAmount,
            dstDomain,
            _toBytes32(address(this)),
            payload,
            srcDomain
        );

        require(cctpMsg.amount == _extractedAmount, BaseBridge_AmountMismatch());
    }

    // ----------- DESTINATION CHAIN ------------
    function handleCCTPMessage(
        bytes calldata cctpMessage,
        bytes calldata attestation
    ) external nonReentrant {
        CCTPMessage memory msgData = handleDestinationMsg(
            cctpMessage,
            attestation
        );

        address market = abi.decode(msgData.payload, (address));
        if (!IRebalancer(rebalancer).isMarketWhitelisted(market)) {
            revert CCTPBridge_InvalidReceiver();
        }

        address underlying = ImTokenMinimal(market).underlying();
        address tokenSent = address(uint160(uint256(msgData.token)));
        if (underlying != tokenSent) revert CCTPBridge_TokenMismatch();

        if (msgData.amount > 0) {
            IERC20(tokenSent).safeTransfer(market, msgData.amount);
        }

        emit Rebalanced(market, msgData.amount);
    }
}
