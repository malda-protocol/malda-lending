# OFTFeeDetail
[Git Source](https://github.com/malda-protocol/malda-lending/blob/7babde64a69e0bddbfb8ee96e52976dd39acebdd/src\interfaces\external\layerzero\v2\ILayerZeroOFT.sol)

*Struct representing OFT fee details.*

*Future proof mechanism to provide a standardized way to communicate fees to things like a UI.*


```solidity
struct OFTFeeDetail {
    int256 feeAmountLD;
    string description;
}
```

