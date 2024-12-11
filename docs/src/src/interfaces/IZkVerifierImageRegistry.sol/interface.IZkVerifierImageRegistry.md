# IZkVerifierImageRegistry
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\IZkVerifierImageRegistry.sol)


## Functions
### getImageForIndex

Returns bytes32 image by index


```solidity
function getImageForIndex(uint256 _index) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|the array index|


### isActive

Returns whitelist state for an image id


```solidity
function isActive(bytes32 _imageId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the bytes32 image id|


### imageIndex

Returns index array for image id


```solidity
function imageIndex(bytes32 _imageId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the bytes32 image id|


