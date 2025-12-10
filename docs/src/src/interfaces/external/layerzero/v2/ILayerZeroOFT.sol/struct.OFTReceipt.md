# OFTReceipt
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol)

Struct representing OFT receipt information.


```solidity
struct OFTReceipt {
uint256 amountSentLD; // Amount of tokens ACTUALLY debited from the sender in local decimals.
// @dev In non-default implementations, the amountReceivedLD COULD differ from this value.
uint256 amountReceivedLD; // Amount of tokens to be received on the remote side.
}
```

