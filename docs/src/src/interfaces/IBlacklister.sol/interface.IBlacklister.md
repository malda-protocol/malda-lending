# IBlacklister
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/IBlacklister.sol)

**Title:**
IBlacklister

**Author:**
Merge Layers Inc.

Interface for blacklisting addresses


## Functions
### blacklist

Blacklists a user immediately (onlyOwner).


```solidity
function blacklist(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to blacklist|


### unblacklist

Removes a user from the blacklist (onlyOwner).


```solidity
function unblacklist(address user) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to unblacklist|


### unblacklist

Removes a user from the blacklist (onlyOwner).


```solidity
function unblacklist(address user, uint256 index) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to unblacklist|
|`index`|`uint256`|The index of the user in blacklist array|


### getBlacklistedAddresses

Returns the list of currently blacklisted addresses.


```solidity
function getBlacklistedAddresses() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|blacklistedAddresses Array of blacklisted addresses|


### isBlacklisted

Returns whether a user is currently blacklisted.


```solidity
function isBlacklisted(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isUserBlacklisted True if the user is blacklisted|


## Events
### Blacklisted
Emitted when a user is blacklisted


```solidity
event Blacklisted(address indexed user);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The blacklisted address|

### Unblacklisted
Emitted when a user is removed from blacklist


```solidity
event Unblacklisted(address indexed user);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The unblacklisted address|

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

### Blacklister_InvalidRoles
Error thrown when roles contract is invalid


```solidity
error Blacklister_InvalidRoles();
```

### Blacklister_NotAllowed
Error thrown when caller is not authorized


```solidity
error Blacklister_NotAllowed();
```

