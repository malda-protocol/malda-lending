# SendParam
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol)

Struct representing token parameters for the OFT send() operation.


```solidity
struct SendParam {
uint32 dstEid; // Destination endpoint ID.
bytes32 to; // Recipient address.
uint256 amountLD; // Amount to send in local decimals.
uint256 minAmountLD; // Minimum amount to send in local decimals.
bytes extraOptions; // Additional options supplied by the caller to be used in the LayerZero message.
bytes composeMsg; // The composed message for the send() operation.
bytes oftCmd; // The OFT command to be executed, unused in default OFT implementations.
}
```

