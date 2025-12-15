# IFeeAdapter
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\everclear\IFeeAdapter.sol)


## Functions
### newIntent


```solidity
function newIntent(
    uint32[] memory _destinations,
    bytes32 _receiver,
    address _inputAsset,
    bytes32 _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data,
    FeeParams calldata _feeParams
) external payable returns (bytes32 _intentId, Intent memory _intent);
```

## Structs
### Intent

```solidity
struct Intent {
    bytes32 initiator;
    bytes32 receiver;
    bytes32 inputAsset;
    bytes32 outputAsset;
    uint24 maxFee;
    uint32 origin;
    uint64 nonce;
    uint48 timestamp;
    uint48 ttl;
    uint256 amount;
    uint32[] destinations;
    bytes data;
}
```

### FeeParams

```solidity
struct FeeParams {
    uint256 fee;
    uint256 deadline;
    bytes sig;
}
```

