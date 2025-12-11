# ZkVerifier
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/verifier/ZkVerifier.sol)

**Inherits:**
Ownable, [IZkVerifier](/src/verifier/ZkVerifier.sol/interface.IZkVerifier.md)

**Title:**
Zero-knowledge verifier wrapper

**Author:**
Malda Protocol

Ownable wrapper around the Risc0 verifier with configurable imageId


## State Variables
### verifier
Current Risc0 verifier contract


```solidity
IRiscZeroVerifier public verifier
```


### imageId
Current Risc0 image identifier


```solidity
bytes32 public imageId
```


## Functions
### constructor

Initializes the verifier wrapper


```solidity
constructor(address owner_, bytes32 _imageId, address _verifier) Ownable(owner_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`|Contract owner|
|`_imageId`|`bytes32`|Risc0 image identifier|
|`_verifier`|`address`|Risc0 verifier contract address|


### setVerifier

Sets the _risc0Verifier address

Admin check is needed on the external method


```solidity
function setVerifier(address _risc0Verifier) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_risc0Verifier`|`address`|the new IRiscZeroVerifier address|


### setImageId

Sets the image id

Admin check is needed on the external method


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

Ensures verifier is configured


```solidity
function _checkAddresses() private view;
```

### __verify

Internal verification against the configured image


```solidity
function __verify(bytes calldata journalEntry, bytes calldata seal) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalEntry`|`bytes`|the Risc0 journal entry|
|`seal`|`bytes`|the Risc0 seal|


## Events
### ImageSet
Emitted when the imageId is updated


```solidity
event ImageSet(bytes32 _imageId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|New image identifier|

### VerifierSet
Emitted when the verifier contract address is updated


```solidity
event VerifierSet(address indexed oldVerifier, address indexed newVerifier);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldVerifier`|`address`|Previous verifier address|
|`newVerifier`|`address`|New verifier address|

## Errors
### ZkVerifier_ImageNotValid
Error thrown when the image id is not valid


```solidity
error ZkVerifier_ImageNotValid();
```

### ZkVerifier_InputNotValid
Error thrown when the input is not valid


```solidity
error ZkVerifier_InputNotValid();
```

### ZkVerifier_VerifierNotSet
Error thrown when the verifier is not set


```solidity
error ZkVerifier_VerifierNotSet();
```

