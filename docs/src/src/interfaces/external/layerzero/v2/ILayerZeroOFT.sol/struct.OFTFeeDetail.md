# OFTFeeDetail
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol)

Struct representing OFT fee details.

Future proof mechanism to provide a standardized way to communicate fees to things like a UI.


```solidity
struct OFTFeeDetail {
int256 feeAmountLD; // Amount of the fee in local decimals.
string description; // Description of the fee.
}
```

