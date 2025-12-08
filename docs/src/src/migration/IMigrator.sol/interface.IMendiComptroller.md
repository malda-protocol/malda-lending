# IMendiComptroller
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/migration/IMigrator.sol)

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


