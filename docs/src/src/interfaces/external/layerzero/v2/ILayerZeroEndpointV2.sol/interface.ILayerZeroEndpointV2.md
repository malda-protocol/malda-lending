# ILayerZeroEndpointV2
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\layerzero\v2\ILayerZeroEndpointV2.sol)

**Inherits:**
[IMessageLibManager](/src\interfaces\external\layerzero\v2\IMessageLibManager.sol\interface.IMessageLibManager.md), [IMessagingComposer](/src\interfaces\external\layerzero\v2\IMessagingComposer.sol\interface.IMessagingComposer.md), [IMessagingChannel](/src\interfaces\external\layerzero\v2\IMessagingChannel.sol\interface.IMessagingChannel.md), [IMessagingContext](/src\interfaces\external\layerzero\v2\IMessagingContext.sol\interface.IMessagingContext.md)


## Functions
### quote


```solidity
function quote(MessagingParams calldata _params, address _sender) external view returns (MessagingFee memory);
```

### send


```solidity
function send(MessagingParams calldata _params, address _refundAddress)
    external
    payable
    returns (MessagingReceipt memory);
```

### verify


```solidity
function verify(Origin calldata _origin, address _receiver, bytes32 _payloadHash) external;
```

### verifiable


```solidity
function verifiable(Origin calldata _origin, address _receiver) external view returns (bool);
```

### initializable


```solidity
function initializable(Origin calldata _origin, address _receiver) external view returns (bool);
```

### lzReceive


```solidity
function lzReceive(
    Origin calldata _origin,
    address _receiver,
    bytes32 _guid,
    bytes calldata _message,
    bytes calldata _extraData
) external payable;
```

### clear


```solidity
function clear(address _oapp, Origin calldata _origin, bytes32 _guid, bytes calldata _message) external;
```

### setLzToken


```solidity
function setLzToken(address _lzToken) external;
```

### lzToken


```solidity
function lzToken() external view returns (address);
```

### nativeToken


```solidity
function nativeToken() external view returns (address);
```

### setDelegate


```solidity
function setDelegate(address _delegate) external;
```

## Events
### PacketSent

```solidity
event PacketSent(bytes encodedPayload, bytes options, address sendLibrary);
```

### PacketVerified

```solidity
event PacketVerified(Origin origin, address receiver, bytes32 payloadHash);
```

### PacketDelivered

```solidity
event PacketDelivered(Origin origin, address receiver);
```

### LzReceiveAlert

```solidity
event LzReceiveAlert(
    address indexed receiver,
    address indexed executor,
    Origin origin,
    bytes32 guid,
    uint256 gas,
    uint256 value,
    bytes message,
    bytes extraData,
    bytes reason
);
```

### LzTokenSet

```solidity
event LzTokenSet(address token);
```

### DelegateSet

```solidity
event DelegateSet(address sender, address delegate);
```

