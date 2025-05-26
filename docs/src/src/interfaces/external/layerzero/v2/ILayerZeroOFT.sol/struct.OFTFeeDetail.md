# OFTFeeDetail
[Git Source](https://github.com/malda-protocol/malda-lending/blob/157d7bccdcadcb7388d89b00ec47106a82e67e78/src\interfaces\external\layerzero\v2\ILayerZeroOFT.sol)

*Struct representing OFT fee details.*

*Future proof mechanism to provide a standardized way to communicate fees to things like a UI.*


```solidity
struct OFTFeeDetail {
    int256 feeAmountLD;
    string description;
}
```

