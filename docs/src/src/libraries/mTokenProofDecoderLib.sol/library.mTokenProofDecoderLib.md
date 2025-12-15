# mTokenProofDecoderLib
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\libraries\mTokenProofDecoderLib.sol)


## State Variables
### ENTRY_SIZE

```solidity
uint256 public constant ENTRY_SIZE = 113;
```


## Functions
### decodeJournal


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
        bool L1inclusion
    );
```

### encodeJournal


```solidity
function encodeJournal(
    address sender,
    address market,
    uint256 accAmountIn,
    uint256 accAmountOut,
    uint32 chainId,
    uint32 dstChainId,
    bool L1inclusion
) internal pure returns (bytes memory);
```

## Errors
### mTokenProofDecoderLib_ChainNotFound

```solidity
error mTokenProofDecoderLib_ChainNotFound();
```

### mTokenProofDecoderLib_InvalidLength

```solidity
error mTokenProofDecoderLib_InvalidLength();
```

### mTokenProofDecoderLib_InvalidInclusion

```solidity
error mTokenProofDecoderLib_InvalidInclusion();
```

