# ImToken
[Git Source](https://github.com/malda-protocol/malda-lending/blob/b62e113034d94e880ebb241b8fad49eb27118646/src\interfaces\ImToken.sol)

**Inherits:**
[ImTokenMinimal](/src\interfaces\ImToken.sol\interface.ImTokenMinimal.md)


## Functions
### totalBorrows

Total amount of outstanding borrows of the underlying in this market


```solidity
function totalBorrows() external view returns (uint256);
```

### borrowIndex

Accumulator of the total earned interest rate since the opening of the market


```solidity
function borrowIndex() external view returns (uint256);
```

### borrowBalanceStored

Returns Borrow balance for account


```solidity
function borrowBalanceStored(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to check for|


### transfer

Moves a `value` amount of tokens from the caller's account to `dst`.
Returns a boolean value indicating whether the operation succeeded.


```solidity
function transfer(address dst, uint256 amount) external returns (bool);
```

### getAccountSnapshot

Get a snapshot of the account's balances, and the cached exchange rate

*This is used by comptroller to more efficiently perform liquidity checks.*


```solidity
function getAccountSnapshot(address account) external view returns (uint256, uint256, uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Address of the account to snapshot|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|(possible error, token balance, borrow balance, exchange rate mantissa)|
|`<none>`|`uint256`||
|`<none>`|`uint256`||
|`<none>`|`uint256`||


### exchangeRateStored

Returns exchange rate


```solidity
function exchangeRateStored() external view returns (uint256);
```

