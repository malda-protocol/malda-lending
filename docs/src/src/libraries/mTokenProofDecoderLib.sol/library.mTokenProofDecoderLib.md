# mTokenProofDecoderLib
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\libraries\mTokenProofDecoderLib.sol)


## State Variables
### ENTRY_SIZE

```solidity
uint256 public constant ENTRY_SIZE = 112;
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
        uint32 dstChainId
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
    uint32 dstChainId
) internal pure returns (bytes memory);
```

## Errors
### mTokenProofDecoderLib_ChainNotFound

```solidity
error mTokenProofDecoderLib_ChainNotFound();
```

