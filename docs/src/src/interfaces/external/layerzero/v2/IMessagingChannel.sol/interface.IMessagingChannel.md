# IMessagingChannel
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\layerzero\v2\IMessagingChannel.sol)


## Functions
### eid


```solidity
function eid() external view returns (uint32);
```

### skip


```solidity
function skip(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce) external;
```

### nilify


```solidity
function nilify(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) external;
```

### burn


```solidity
function burn(address _oapp, uint32 _srcEid, bytes32 _sender, uint64 _nonce, bytes32 _payloadHash) external;
```

### nextGuid


```solidity
function nextGuid(address _sender, uint32 _dstEid, bytes32 _receiver) external view returns (bytes32);
```

### inboundNonce


```solidity
function inboundNonce(address _receiver, uint32 _srcEid, bytes32 _sender) external view returns (uint64);
```

### outboundNonce


```solidity
function outboundNonce(address _sender, uint32 _dstEid, bytes32 _receiver) external view returns (uint64);
```

### inboundPayloadHash


```solidity
function inboundPayloadHash(address _receiver, uint32 _srcEid, bytes32 _sender, uint64 _nonce)
    external
    view
    returns (bytes32);
```

### lazyInboundNonce


```solidity
function lazyInboundNonce(address _receiver, uint32 _srcEid, bytes32 _sender) external view returns (uint64);
```

## Events
### InboundNonceSkipped

```solidity
event InboundNonceSkipped(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce);
```

### PacketNilified

```solidity
event PacketNilified(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce, bytes32 payloadHash);
```

### PacketBurnt

```solidity
event PacketBurnt(uint32 srcEid, bytes32 sender, address receiver, uint64 nonce, bytes32 payloadHash);
```

