# BatchSubmitter
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/mToken/BatchSubmitter.sol)

**Inherits:**
Ownable

**Title:**
BatchSubmitter

**Author:**
Merge Layers Inc.

Contract for batch processing multiple operations


## State Variables
### MINT_SELECTOR
The function selector for the supported `mintExternal` operation


```solidity
bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector
```


### REPAY_SELECTOR
The function selector for the supported `repayExternal` operation


```solidity
bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector
```


### OUT_HERE_SELECTOR
The function selector for the supported `outHere` operation


```solidity
bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector
```


### LIQUIDATE_SELECTOR
The function selector for the supported `liquidateExternal` operation


```solidity
bytes4 internal constant LIQUIDATE_SELECTOR = ImErc20Host.liquidateExternal.selector
```


### ROLES_OPERATOR
The roles contract for access control


```solidity
IRoles public immutable ROLES_OPERATOR
```


### verifier
The ZkVerifier contract


```solidity
IZkVerifier public verifier
```


## Functions
### constructor

Constructor


```solidity
constructor(address _roles, address _zkVerifier, address owner_) Ownable(owner_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|The roles contract address|
|`_zkVerifier`|`address`|The ZkVerifier contract address|
|`owner_`|`address`|The owner address|


### updateZkVerifier

Updates IZkVerifier address


```solidity
function updateZkVerifier(address _zkVerifier) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_zkVerifier`|`address`|the verifier address|


### batchProcess

Execute multiple operations in a single transaction


```solidity
function batchProcess(BatchProcessMsg calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`BatchProcessMsg`|The batch process message data|


### _verifyProof

Verifies the proof using ZkVerifier


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data to verify|
|`seal`|`bytes`|The seal data for verification|


## Events
### BatchProcessFailed
Event emitted when batch process fails


```solidity
event BatchProcessFailed(
    bytes32 initHash,
    address receiver,
    address mToken,
    uint256 amount,
    uint256 minAmountOut,
    bytes4 selector,
    bytes reason
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initHash`|`bytes32`|The initialization hash|
|`receiver`|`address`|The receiver address|
|`mToken`|`address`|The mToken address|
|`amount`|`uint256`|The amount|
|`minAmountOut`|`uint256`|The minimum amount out|
|`selector`|`bytes4`|The function selector|
|`reason`|`bytes`|The failure reason|

### BatchProcessSuccess
Event emitted when batch process succeeds


```solidity
event BatchProcessSuccess(
    bytes32 initHash, address receiver, address mToken, uint256 amount, uint256 minAmountOut, bytes4 selector
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initHash`|`bytes32`|The initialization hash|
|`receiver`|`address`|The receiver address|
|`mToken`|`address`|The mToken address|
|`amount`|`uint256`|The amount|
|`minAmountOut`|`uint256`|The minimum amount out|
|`selector`|`bytes4`|The function selector|

### ZkVerifierUpdated
Event emitted when ZkVerifier is updated


```solidity
event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldVerifier`|`address`|The old verifier address|
|`newVerifier`|`address`|The new verifier address|

## Errors
### BatchSubmitter_CallerNotAllowed
Error thrown when caller is not allowed


```solidity
error BatchSubmitter_CallerNotAllowed();
```

### BatchSubmitter_JournalNotValid
Error thrown when journal is not valid


```solidity
error BatchSubmitter_JournalNotValid();
```

### BatchSubmitter_InvalidSelector
Error thrown when selector is invalid


```solidity
error BatchSubmitter_InvalidSelector();
```

### BatchSubmitter_AddressNotValid
Error thrown when address is not valid


```solidity
error BatchSubmitter_AddressNotValid();
```

## Structs
### BatchProcessMsg
Parameters used to process a batch of operations


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
    address[] userToLiquidate;
    address[] collateral;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`receivers`|`address[]`|Funds receivers|
|`journalData`|`bytes`|Encoded journal data|
|`seal`|`bytes`|Seal data for verification|
|`mTokens`|`address[]`|Array of mToken addresses|
|`amounts`|`uint256[]`|Array of amounts for each operation|
|`minAmountsOut`|`uint256[]`|Array of minimum output amounts|
|`selectors`|`bytes4[]`|Array of function selectors for each operation|
|`initHashes`|`bytes32[]`|Array of initial hashes for journals|
|`startIndex`|`uint256`|Start index for processing journals|
|`userToLiquidate`|`address[]`|Array of users to liquidate (for liquidateExternal operations)|
|`collateral`|`address[]`|Array of collateral addresses (for liquidateExternal operations)|

