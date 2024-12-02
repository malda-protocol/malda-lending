# ImTokenMinimal
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\ImToken.sol)


## Functions
### name

EIP-20 token name for this token


```solidity
function name() external view returns (string memory);
```

### symbol

EIP-20 token symbol for this token


```solidity
function symbol() external view returns (string memory);
```

### decimals

EIP-20 token decimals for this token


```solidity
function decimals() external view returns (uint8);
```

### totalSupply

Returns the value of tokens in existence.


```solidity
function totalSupply() external view returns (uint256);
```

### balanceOf

Returns the value of tokens owned by `account`.


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to check for|


### isMToken

*Returns true*


```solidity
function isMToken() external view returns (bool);
```

