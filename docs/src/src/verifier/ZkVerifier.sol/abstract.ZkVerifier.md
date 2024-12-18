# ZkVerifier
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\verifier\ZkVerifier.sol)


## State Variables
### verifier

```solidity
IRiscZeroVerifier public verifier;
```


### verifierImageRegistry

```solidity
IZkVerifierImageRegistry public verifierImageRegistry;
```


### _verifierInitialized

```solidity
bool private _verifierInitialized;
```


## Functions
### initialize

Initializes a new ZkVerifier contract


```solidity
function initialize(address _verifier, address _verifierImageRegistry) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_verifier`|`address`|IRiscZeroVerifier contract implementation|
|`_verifierImageRegistry`|`address`||


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


### _setVerifierImageRegistry

Sets the IZkVerifierImageRegistry

*Admin check is needed on the external method*


```solidity
function _setVerifierImageRegistry(address _imageRegistry) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageRegistry`|`address`|the new image registry address|


### _verifyInput

Verifies an input


```solidity
function _verifyInput(bytes calldata journalEntry, bytes calldata seal, uint256 imageIdIndex) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalEntry`|`bytes`|the risc0 journal entry|
|`seal`|`bytes`|the risc0 seal|
|`imageIdIndex`|`uint256`|the risc0 imageId index available in the registry|


### _verifyInput

Verifies an input


```solidity
function _verifyInput(bytes calldata journalEntry, bytes calldata seal, bytes32 imageId) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalEntry`|`bytes`|the risc0 journal entry|
|`seal`|`bytes`|the risc0 seal|
|`imageId`|`bytes32`|the risc0 imageId|


### _verifyBatchInput

Batch verifies inputs


```solidity
function _verifyBatchInput(VerifierBatchData calldata list) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`list`|`VerifierBatchData`|the batch entry for risc0 parameters|


### _checkImage


```solidity
function _checkImage(bytes32 imageId, uint256 _imageIndex) private view returns (bytes32);
```

### _checkAddresses

*if imageId was provided, check it directly; otherwise get it by index*


```solidity
function _checkAddresses() private view;
```

### __verify


```solidity
function __verify(bytes calldata journalEntry, bytes calldata seal, bytes32 imageId) private view;
```

## Events
### VerifierSet

```solidity
event VerifierSet(address indexed oldVerifier, address indexed newVerifier);
```

### VerifierImageRegistrySet

```solidity
event VerifierImageRegistrySet(address indexed oldRegistry, address indexed newRegistry);
```

## Errors
### ZkVerifier_OnlyAdmin

```solidity
error ZkVerifier_OnlyAdmin();
```

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

### ZkVerifier_AlreadyInitialized

```solidity
error ZkVerifier_AlreadyInitialized();
```

### ZkVerifier_VerifierImageRegistryNotSet

```solidity
error ZkVerifier_VerifierImageRegistryNotSet();
```

## Structs
### VerifierBatchData

```solidity
struct VerifierBatchData {
    bytes[] journalEntries;
    bytes[] seals;
    bytes32[] imageIds;
    uint256[] imageIdIndexes;
}
```

