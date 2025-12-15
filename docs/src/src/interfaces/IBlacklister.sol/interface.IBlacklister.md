# IBlacklister
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\IBlacklister.sol)


## Functions
### getBlacklistedAddresses

Returns the list of currently blacklisted addresses.


```solidity
function getBlacklistedAddresses() external view returns (address[] memory);
```

### isBlacklisted

Returns whether a user is currently blacklisted.


```solidity
function isBlacklisted(address user) external view returns (bool);
```

### blacklist

Blacklists a user immediately (onlyOwner).


```solidity
function blacklist(address user) external;
```

### unblacklist

Removes a user from the blacklist (onlyOwner).


```solidity
function unblacklist(address user) external;
```

## Events
### Blacklisted

```solidity
event Blacklisted(address indexed user);
```

### Unblacklisted

```solidity
event Unblacklisted(address indexed user);
```

