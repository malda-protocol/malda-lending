# IGasFeesHelper
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/IGasFeesHelper.sol)

**Author:**
Merge Layers Inc.

Interface for retrieving per-chain gas fee configuration


## Functions
### gasFees

Returns the gas fee for a destination chain


```solidity
function gasFees(uint32 dstChainId) external view returns (uint256 fee);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|Destination chain identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Gas fee amount|


