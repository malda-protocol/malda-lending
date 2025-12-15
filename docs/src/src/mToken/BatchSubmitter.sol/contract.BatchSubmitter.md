# BatchSubmitter
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\mToken\BatchSubmitter.sol)

**Inherits:**
Ownable


## State Variables
### rolesOperator
The roles contract for access control


```solidity
IRoles public immutable rolesOperator;
```


### verifier

```solidity
IZkVerifier public verifier;
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
constructor(address _roles, address _zkVerifier, address _owner) Ownable(_owner);
```

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

### BatchProcessSuccess

```solidity
event BatchProcessSuccess(
    bytes32 initHash, address receiver, address mToken, uint256 amount, uint256 minAmountOut, bytes4 selector
);
```

### ZkVerifierUpdated

```solidity
event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
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

### BatchSubmitter_AddressNotValid

```solidity
error BatchSubmitter_AddressNotValid();
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

