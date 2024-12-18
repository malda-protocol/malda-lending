# IOracleOperator
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\interfaces\IOracleOperator.sol)

Prices are returned in USD


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


