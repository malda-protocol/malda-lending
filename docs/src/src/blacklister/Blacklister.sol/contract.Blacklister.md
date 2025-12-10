# Blacklister
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/blacklister/Blacklister.sol)

**Inherits:**
OwnableUpgradeable, [IBlacklister](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/IBlacklister.sol/interface.IBlacklister.md)

**Author:**
Merge Layers Inc.

Contract for managing blacklisted addresses


## State Variables
### isBlacklisted
Mapping of addresses to their blacklist status


```solidity
mapping(address user => bool isBlacklisted) public isBlacklisted
```


### _blacklistedList
List of blacklisted addresses


```solidity
address[] private _blacklistedList
```


### rolesOperator
The roles operator contract


```solidity
IRoles public rolesOperator
```


## Functions
### onlyOwnerOrGuardian

Modifier to restrict access to owner or has guardian blacklist role


```solidity
modifier onlyOwnerOrGuardian() ;
```

### constructor

Disables initializers on implementation contract

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### initialize

Initialize the contract


```solidity
function initialize(address payable _owner, address _roles) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address payable`|The owner address|
|`_roles`|`address`|The roles contract address|


### blacklist

Blacklists a user immediately (onlyOwner).


```solidity
function blacklist(address user) external override onlyOwnerOrGuardian;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to blacklist|


### unblacklist

Removes a user from the blacklist (onlyOwner).


```solidity
function unblacklist(address user) external override onlyOwnerOrGuardian;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to unblacklist|


### unblacklist

Removes a user from the blacklist (onlyOwner).


```solidity
function unblacklist(address user, uint256 index) external override onlyOwnerOrGuardian;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to unblacklist|
|`index`|`uint256`||


### getBlacklistedAddresses

Returns the list of currently blacklisted addresses.


```solidity
function getBlacklistedAddresses() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|blacklistedAddresses Array of blacklisted addresses|


### _addToBlacklist

Internal function to add an address to blacklist


```solidity
function _addToBlacklist(address user) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to blacklist|


### _removeFromBlacklist

Internal function to remove an address from blacklist list


```solidity
function _removeFromBlacklist(address user) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to remove|


### _removeFromBlacklist

Internal function to remove an address from blacklist list by index


```solidity
function _removeFromBlacklist(address user, uint256 index) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to remove|
|`index`|`uint256`|The index in the blacklist array|


