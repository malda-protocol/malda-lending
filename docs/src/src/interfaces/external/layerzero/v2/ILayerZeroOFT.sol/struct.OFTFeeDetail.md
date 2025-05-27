# OFTFeeDetail
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\interfaces\external\layerzero\v2\ILayerZeroOFT.sol)

*Struct representing OFT fee details.*

*Future proof mechanism to provide a standardized way to communicate fees to things like a UI.*


```solidity
struct OFTFeeDetail {
    int256 feeAmountLD;
    string description;
}
```

