# ZkVerifierImageRegistry
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\verifier\ZkVerifierImageRegistry.sol)

**Inherits:**
Ownable, [IZkVerifierImageRegistry](/src\interfaces\IZkVerifierImageRegistry.sol\interface.IZkVerifierImageRegistry.md)


## State Variables
### isActive
Returns whitelist state for an image id


```solidity
mapping(bytes32 => bool) public override isActive;
```


### imageIndex
Returns index array for image id


```solidity
mapping(bytes32 => uint256) public override imageIndex;
```


### imageIds
Array for registered image ids


```solidity
bytes32[] public imageIds;
```


## Functions
### constructor


```solidity
constructor(address _owner) Ownable(_owner);
```

### getImageForIndex

Returns bytes32 image by index


```solidity
function getImageForIndex(uint256 _index) external view override returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_index`|`uint256`|the array index|


### addImageId

Registers a new image id


```solidity
function addImageId(bytes32 _newImageId) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newImageId`|`bytes32`|the new bytes32 verification image id|


### disableImageId

Disables existing image id


```solidity
function disableImageId(bytes32 _imageId) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the existing bytes32 verification image id|


## Events
### ImageAdded

```solidity
event ImageAdded(bytes32 imageId, uint256 index);
```

## Errors
### ZkVerifierImagesRegistry_AlredyRegistered

```solidity
error ZkVerifierImagesRegistry_AlredyRegistered();
```

