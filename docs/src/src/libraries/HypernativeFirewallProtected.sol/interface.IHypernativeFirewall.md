# IHypernativeFirewall
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/libraries/HypernativeFirewallProtected.sol)

**Title:**
IHypernativeFirewall

**Author:**
Merge Layers Inc.

Interface for the HypernativeFirewall contract


## Functions
### register

Registers an account with the firewall


```solidity
function register(address account, bool isStrictMode) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to register|
|`isStrictMode`|`bool`|The strict mode|


### validateBlacklistedAccountInteraction

Validates the blacklisted account interaction


```solidity
function validateBlacklistedAccountInteraction(address sender) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The sender of the transaction|


### validateForbiddenAccountInteraction

Validates the forbidden account interaction


```solidity
function validateForbiddenAccountInteraction(address sender) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The sender of the transaction|


### validateForbiddenContextInteraction

Validates the forbidden context interaction


```solidity
function validateForbiddenContextInteraction(address origin, address sender) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`origin`|`address`|The origin of the transaction|
|`sender`|`address`|The sender of the transaction|


