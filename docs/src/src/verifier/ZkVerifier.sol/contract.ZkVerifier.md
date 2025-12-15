# ZkVerifier
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\verifier\ZkVerifier.sol)

**Inherits:**
Ownable, [IZkVerifier](/src\verifier\ZkVerifier.sol\interface.IZkVerifier.md)


## State Variables
### verifier

```solidity
IRiscZeroVerifier public verifier;
```


### imageId

```solidity
bytes32 public imageId;
```


## Functions
### constructor


```solidity
constructor(address _owner, bytes32 _imageId, address _verifier) Ownable(_owner);
```

### setVerifier

Sets the _risc0Verifier address

*Admin check is needed on the external method*


```solidity
function setVerifier(address _risc0Verifier) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_risc0Verifier`|`address`|the new IRiscZeroVerifier address|


### setImageId

Sets the image id

*Admin check is needed on the external method*


```solidity
function setImageId(bytes32 _imageId) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the new image id|


### verifyInput

Verifies an input


```solidity
function verifyInput(bytes calldata journalEntry, bytes calldata seal) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalEntry`|`bytes`|the risc0 journal entry|
|`seal`|`bytes`|the risc0 seal|


### _checkAddresses


```solidity
function _checkAddresses() private view;
```

### __verify


```solidity
function __verify(bytes calldata journalEntry, bytes calldata seal) private view;
```

## Events
### ImageSet

```solidity
event ImageSet(bytes32 _imageId);
```

### VerifierSet

```solidity
event VerifierSet(address indexed oldVerifier, address indexed newVerifier);
```

## Errors
### ZkVerifier_ImageNotValid

```solidity
error ZkVerifier_ImageNotValid();
```

### ZkVerifier_InputNotValid

```solidity
error ZkVerifier_InputNotValid();
```

### ZkVerifier_VerifierNotSet

```solidity
error ZkVerifier_VerifierNotSet();
```

