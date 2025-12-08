# CommonLib
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/libraries/CommonLib.sol)

**Author:**
Merge Layers Inc.

Shared helper utilities for validation and math


## Functions
### checkHostToExtension

Checks a host to extension call for validity


```solidity
function checkHostToExtension(
    uint256 amount,
    uint32 dstChainId,
    uint256 msgValue,
    mapping(uint32 => bool) storage allowedChains,
    IGasFeesHelper gasHelper
) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount being transferred|
|`dstChainId`|`uint32`|Destination chain id|
|`msgValue`|`uint256`|Message value provided|
|`allowedChains`|`mapping(uint32 => bool)`|Mapping of allowed chain ids|
|`gasHelper`|`IGasFeesHelper`|Gas helper contract|


### checkLengthMatch

Ensures two lengths match


```solidity
function checkLengthMatch(uint256 l1, uint256 l2) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`l1`|`uint256`|First length|
|`l2`|`uint256`|Second length|


### checkLengthMatch

Ensures three lengths match


```solidity
function checkLengthMatch(uint256 l1, uint256 l2, uint256 l3) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`l1`|`uint256`|First length|
|`l2`|`uint256`|Second length|
|`l3`|`uint256`|Third length|


### computeSum

Computes sum of an array


```solidity
function computeSum(uint256[] calldata values) internal pure returns (uint256 sum);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`values`|`uint256[]`|Array of values|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sum`|`uint256`|Total sum|


## Errors
### CommonLib_LengthMismatch
Thrown when array lengths mismatch


```solidity
error CommonLib_LengthMismatch();
```

### AmountNotValid
Thrown when amount is invalid


```solidity
error AmountNotValid();
```

### ChainNotValid
Thrown when chain id is not allowed


```solidity
error ChainNotValid();
```

### NotEnoughGasFee
Thrown when provided gas fee is insufficient


```solidity
error NotEnoughGasFee();
```

