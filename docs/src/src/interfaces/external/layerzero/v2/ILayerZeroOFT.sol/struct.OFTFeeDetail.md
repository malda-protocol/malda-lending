# OFTFeeDetail
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol)

Struct representing OFT fee details.

Future proof mechanism to provide a standardized way to communicate fees to things like a UI.


```solidity
struct OFTFeeDetail {
int256 feeAmountLD; // Amount of the fee in local decimals.
string description; // Description of the fee.
}
```

