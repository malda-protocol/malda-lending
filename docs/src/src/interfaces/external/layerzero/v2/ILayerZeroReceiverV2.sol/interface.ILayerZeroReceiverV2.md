# ILayerZeroReceiverV2
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\interfaces\external\layerzero\v2\ILayerZeroReceiverV2.sol)


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

