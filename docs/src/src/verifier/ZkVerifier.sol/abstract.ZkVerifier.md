# ZkVerifier
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\verifier\ZkVerifier.sol)

**Inherits:**
Initializable


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
### initialize

Initializes a new ZkVerifier contract


```solidity
function initialize(address _verifier) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_verifier`|`address`|IRiscZeroVerifier contract implementation|


### _setVerifier

Sets the _risc0Verifier address

*Admin check is needed on the external method*


```solidity
function _setVerifier(address _risc0Verifier) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_risc0Verifier`|`address`|the new IRiscZeroVerifier address|


### _setImageId

Sets the image id

*Admin check is needed on the external method*


```solidity
function _setImageId(bytes32 _imageId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the new image id|


### _verifyInput

Verifies an input


```solidity
function _verifyInput(bytes calldata journalEntry, bytes calldata seal) internal virtual;
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

