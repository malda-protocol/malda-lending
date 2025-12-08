# ILayerZeroReceiverV2
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/external/layerzero/v2/ILayerZeroReceiverV2.sol)


## Functions
### allowInitializePath


```solidity
function allowInitializePath(Origin calldata _origin) external view returns (bool);
```

### nextNonce


```solidity
function nextNonce(uint32 _eid, bytes32 _sender) external view returns (uint64);
```

### lzReceive


```solidity
function lzReceive(
    Origin calldata _origin,
    bytes32 _guid,
    bytes calldata _message,
    address _executor,
    bytes calldata _extraData
) external payable;
```

