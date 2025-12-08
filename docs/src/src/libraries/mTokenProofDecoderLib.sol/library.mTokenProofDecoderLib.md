# mTokenProofDecoderLib
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/libraries/mTokenProofDecoderLib.sol)

**Author:**
Merge Layers Inc.

Utility library for encoding and decoding mToken journals


## State Variables
### ENTRY_SIZE
Encoded journal entry size in bytes


```solidity
uint256 public constant ENTRY_SIZE = 113
```


## Functions
### decodeJournal

Decodes encoded journal data into fields


```solidity
function decodeJournal(bytes memory journalData)
    internal
    pure
    returns (
        address sender,
        address market,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint32 chainId,
        uint32 dstChainId,
        bool l1Inclusion
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|Packed journal bytes|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Journal sender|
|`market`|`address`|Market address|
|`accAmountIn`|`uint256`|Accumulated amount in|
|`accAmountOut`|`uint256`|Accumulated amount out|
|`chainId`|`uint32`|Source chain id|
|`dstChainId`|`uint32`|Destination chain id|
|`l1Inclusion`|`bool`|Whether L1 inclusion is required|


### encodeJournal

Encodes journal fields into packed bytes


```solidity
function encodeJournal(
    address sender,
    address market,
    uint256 accAmountIn,
    uint256 accAmountOut,
    uint32 chainId,
    uint32 dstChainId,
    bool l1Inclusion
) internal pure returns (bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Journal sender|
|`market`|`address`|Market address|
|`accAmountIn`|`uint256`|Accumulated amount in|
|`accAmountOut`|`uint256`|Accumulated amount out|
|`chainId`|`uint32`|Source chain id|
|`dstChainId`|`uint32`|Destination chain id|
|`l1Inclusion`|`bool`|Whether L1 inclusion is required|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|Packed journal bytes|


## Errors
### mTokenProofDecoderLib_ChainNotFound
Thrown when chain is not found


```solidity
error mTokenProofDecoderLib_ChainNotFound();
```

### mTokenProofDecoderLib_InvalidLength
Thrown when journal length is invalid


```solidity
error mTokenProofDecoderLib_InvalidLength();
```

### mTokenProofDecoderLib_InvalidInclusion
Thrown when L1 inclusion flag is invalid


```solidity
error mTokenProofDecoderLib_InvalidInclusion();
```

