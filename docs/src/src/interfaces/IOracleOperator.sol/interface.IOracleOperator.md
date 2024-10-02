# IOracleOperator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/179a048ba4fdf7caff4add1e6a0986ba27ae405c/src\interfaces\IOracleOperator.sol)


## Functions
### getPrice

Get the price of a mToken asset


```solidity
function getPrice(address mToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The mToken to get the price of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The underlying asset price mantissa (scaled by 1e18). Zero means the price is unavailable.|


### getUnderlyingPrice

Get the underlying price of a mToken asset


```solidity
function getUnderlyingPrice(address mToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The mToken to get the underlying price of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The underlying asset price mantissa (scaled by 1e18). Zero means the price is unavailable.|


