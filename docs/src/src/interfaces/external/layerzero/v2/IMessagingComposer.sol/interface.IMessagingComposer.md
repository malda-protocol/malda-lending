# IMessagingComposer
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\layerzero\v2\IMessagingComposer.sol)


## Functions
### composeQueue


```solidity
function composeQueue(address _from, address _to, bytes32 _guid, uint16 _index)
    external
    view
    returns (bytes32 messageHash);
```

### sendCompose


```solidity
function sendCompose(address _to, bytes32 _guid, uint16 _index, bytes calldata _message) external;
```

### lzCompose


```solidity
function lzCompose(
    address _from,
    address _to,
    bytes32 _guid,
    uint16 _index,
    bytes calldata _message,
    bytes calldata _extraData
) external payable;
```

## Events
### ComposeSent

```solidity
event ComposeSent(address from, address to, bytes32 guid, uint16 index, bytes message);
```

### ComposeDelivered

```solidity
event ComposeDelivered(address from, address to, bytes32 guid, uint16 index);
```

### LzComposeAlert

```solidity
event LzComposeAlert(
    address indexed from,
    address indexed to,
    address indexed executor,
    bytes32 guid,
    uint16 index,
    uint256 gas,
    uint256 value,
    bytes message,
    bytes extraData,
    bytes reason
);
```

