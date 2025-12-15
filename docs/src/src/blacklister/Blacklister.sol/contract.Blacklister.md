# Blacklister
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\blacklister\Blacklister.sol)

**Inherits:**
OwnableUpgradeable, [IBlacklister](/src\interfaces\IBlacklister.sol\interface.IBlacklister.md)


## State Variables
### isBlacklisted

```solidity
mapping(address => bool) public isBlacklisted;
```


### _blacklistedList

```solidity
address[] private _blacklistedList;
```


### rolesOperator

```solidity
IRoles public rolesOperator;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(address payable _owner, address _roles) external initializer;
```

### onlyOwnerOrGuardian


```solidity
modifier onlyOwnerOrGuardian();
```

### getBlacklistedAddresses


```solidity
function getBlacklistedAddresses() external view returns (address[] memory);
```

### blacklist


```solidity
function blacklist(address user) external override onlyOwnerOrGuardian;
```

### unblacklist


```solidity
function unblacklist(address user) external override onlyOwnerOrGuardian;
```

### _addToBlacklist


```solidity
function _addToBlacklist(address user) internal;
```

### _removeFromBlacklistList


```solidity
function _removeFromBlacklistList(address user) internal;
```

## Errors
### Blacklister_AlreadyBlacklisted

```solidity
error Blacklister_AlreadyBlacklisted();
```

### Blacklister_NotBlacklisted

```solidity
error Blacklister_NotBlacklisted();
```

### Blacklister_NotAllowed

```solidity
error Blacklister_NotAllowed();
```

