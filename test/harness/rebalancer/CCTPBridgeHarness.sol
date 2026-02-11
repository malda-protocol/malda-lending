// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";

contract CCTPBridgeHarness is CCTPBridge {
    constructor(address _roles, address _tokenMessenger, address _messageTransmitter, address _rebalancer)
        CCTPBridge(_roles, _tokenMessenger, _messageTransmitter, _rebalancer)
    {}

    function harnessSetDomain(uint32 chainId, uint32 domain) external {
        chainIdToDomain[chainId] = domain;
        domainSet[chainId] = true;
    }

    function harnessSetAcceptedToken(address token, bool allowed) external {
        acceptedTokens[token] = allowed;
    }
}
