# BatchSubmitter
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\mToken\BatchSubmitter.sol)

**Inherits:**
[ZkVerifier](/src\verifier\ZkVerifier.sol\abstract.ZkVerifier.md), Ownable


## State Variables
### rolesOperator
The roles contract for access control


```solidity
IRoles public immutable rolesOperator;
```


### MINT_SELECTOR

```solidity
bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector;
```


### REPAY_SELECTOR

```solidity
bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector;
```


### OUT_HERE_SELECTOR

```solidity
bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector;
```


## Functions
### constructor


```solidity
constructor(address _roles, address zkVerifier_, address _owner) Ownable(_owner);
```

### setVerifier

Sets the _risc0Verifier address


```solidity
function setVerifier(address _risc0Verifier) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_risc0Verifier`|`address`|the new IRiscZeroVerifier address|


### setImageId

Sets the image id


```solidity
function setImageId(bytes32 _imageId) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the new image id|


### batchProcess

Execute multiple operations in a single transaction


```solidity
function batchProcess(BatchProcessMsg calldata data) external;
```

### _verifyProof

Verifies the proof using ZkVerifier


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data to verify|
|`seal`|`bytes`|The seal data for verification|


## Events
### BatchProcessFailed

```solidity
event BatchProcessFailed(bytes32 initHash, bytes reason);
```

### BatchProcessSuccess

```solidity
event BatchProcessSuccess(bytes32 initHash);
```

## Errors
### BatchSubmitter_CallerNotAllowed

```solidity
error BatchSubmitter_CallerNotAllowed();
```

### BatchSubmitter_JournalNotValid

```solidity
error BatchSubmitter_JournalNotValid();
```

### BatchSubmitter_InvalidSelector

```solidity
error BatchSubmitter_InvalidSelector();
```

## Structs
### BatchProcessMsg
receiver Funds receiver/performed on
journalData The encoded journal data
seal The seal data for verification
mTokens Array of mToken addresses
amounts Array of amounts for each operation
selectors Array of function selectors for each operation
startIndex Start index for processing journals
endIndex End index for processing journals (exclusive)


```solidity
struct BatchProcessMsg {
    address[] receivers;
    bytes journalData;
    bytes seal;
    address[] mTokens;
    uint256[] amounts;
    uint256[] minAmountsOut;
    bytes4[] selectors;
    bytes32[] initHashes;
    uint256 startIndex;
}
```

