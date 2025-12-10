# IMendiComptroller
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/migration/IMigrator.sol)

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


