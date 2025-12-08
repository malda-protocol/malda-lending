# Blacklister
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/blacklister/Blacklister.sol)

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

Modifier to restrict access to owner or guardian


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

Blacklist an address


```solidity
function blacklist(address user) external override onlyOwnerOrGuardian;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to blacklist|


### unblacklist

Remove an address from blacklist


```solidity
function unblacklist(address user) external override onlyOwnerOrGuardian;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to unblacklist|


### unblacklist

Remove an address from blacklist by index


```solidity
function unblacklist(address user, uint256 index) external override onlyOwnerOrGuardian;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to unblacklist|
|`index`|`uint256`|The index in the blacklist array|


### getBlacklistedAddresses

Get all blacklisted addresses


```solidity
function getBlacklistedAddresses() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of blacklisted addresses|


### _addToBlacklist

Internal function to add an address to blacklist


```solidity
function _addToBlacklist(address user) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to blacklist|


### _removeFromBlacklistList

Internal function to remove an address from blacklist list


```solidity
function _removeFromBlacklistList(address user) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to remove|


### _removeFromBlacklistList

Internal function to remove an address from blacklist list by index


```solidity
function _removeFromBlacklistList(address user, uint256 index) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to remove|
|`index`|`uint256`|The index in the blacklist array|


## Errors
### Blacklister_AlreadyBlacklisted
Error thrown when address is already blacklisted


```solidity
error Blacklister_AlreadyBlacklisted();
```

### Blacklister_NotBlacklisted
Error thrown when address is not blacklisted


```solidity
error Blacklister_NotBlacklisted();
```

### Blacklister_NotAllowed
Error thrown when caller is not authorized


```solidity
error Blacklister_NotAllowed();
```

