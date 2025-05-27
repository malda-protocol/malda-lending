# SendParam
[Git Source](https://github.com/malda-protocol/malda-lending/blob/acd5ab2b6c54b66703c366d922b6691b77a8c9fd/src\interfaces\external\layerzero\v2\ILayerZeroOFT.sol)

*Struct representing token parameters for the OFT send() operation.*


```solidity
struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}
```

