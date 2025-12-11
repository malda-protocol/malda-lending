# IGasFeesHelper
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/IGasFeesHelper.sol)

**Title:**
IGasFeesHelper

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


