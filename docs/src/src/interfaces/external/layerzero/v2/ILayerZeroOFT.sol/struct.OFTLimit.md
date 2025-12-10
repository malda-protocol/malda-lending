# OFTLimit
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol)

Struct representing OFT limit information.

These amounts can change dynamically and are up the the specific oft implementation.


```solidity
struct OFTLimit {
uint256 minAmountLD; // Minimum amount in local decimals that can be sent to the recipient.
uint256 maxAmountLD; // Maximum amount in local decimals that can be sent to the recipient.
}
```

