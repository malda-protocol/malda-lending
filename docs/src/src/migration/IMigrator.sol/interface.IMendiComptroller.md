# IMendiComptroller
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/migration/IMigrator.sol)

**Title:**
IMendiComptroller

**Author:**
Merge Layers Inc.

Interface for fetching entered markets


## Functions
### getAssetsIn

Returns assets in for account


```solidity
function getAssetsIn(address account) external view returns (IMendiMarket[] memory assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Account address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`IMendiMarket[]`|List of markets|


