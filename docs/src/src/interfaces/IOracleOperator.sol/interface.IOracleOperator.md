# IOracleOperator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/interfaces/IOracleOperator.sol)

**Author:**
Merge Layers Inc.

Oracle operator interface returning USD prices


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
|`<none>`|`uint256`|price The underlying asset price mantissa (scaled by 1e18). Zero means unavailable.|


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
|`<none>`|`uint256`|price The underlying asset price mantissa (scaled by 1e18). Zero means unavailable.|


