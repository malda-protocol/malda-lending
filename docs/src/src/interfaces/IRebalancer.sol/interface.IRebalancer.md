# IRebalancer
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\IRebalancer.sol)


## Functions
### nonce

returns current nonce


```solidity
function nonce() external view returns (uint256);
```

### isBridgeWhitelisted

returns if a bridge implementation is whitelisted


```solidity
function isBridgeWhitelisted(address bridge) external view returns (bool);
```

### isDestinationWhitelisted

returns if a destination is whitelisted


```solidity
function isDestinationWhitelisted(uint32 dstId) external view returns (bool);
```

### sendMsg

sends a bridge message


```solidity
function sendMsg(address bridge, address _market, uint256 _amount, Msg calldata msg) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|the whitelisted bridge address|
|`_market`|`address`|the market to rebalance from address|
|`_amount`|`uint256`|the amount to rebalance|
|`msg`|`Msg`|the message data|


## Events
### BridgeWhitelistedStatusUpdated

```solidity
event BridgeWhitelistedStatusUpdated(address indexed bridge, bool status);
```

### MsgSent

```solidity
event MsgSent(
    address indexed bridge, uint32 indexed dstChainId, address indexed token, bytes message, bytes bridgeData
);
```

### EthSaved

```solidity
event EthSaved(uint256 amount);
```

### MaxTransferSizeUpdated

```solidity
event MaxTransferSizeUpdated(uint32 indexed dstChainId, address indexed token, uint256 newLimit);
```

### MinTransferSizeUpdated

```solidity
event MinTransferSizeUpdated(uint32 indexed dstChainId, address indexed token, uint256 newLimit);
```

### DestinationWhitelistedStatusUpdated

```solidity
event DestinationWhitelistedStatusUpdated(uint32 indexed dstChainId, bool status);
```

### AllowedListUpdated

```solidity
event AllowedListUpdated(address[] list, bool status);
```

## Errors
### Rebalancer_NotAuthorized

```solidity
error Rebalancer_NotAuthorized();
```

### Rebalancer_MarketNotValid

```solidity
error Rebalancer_MarketNotValid();
```

### Rebalancer_RequestNotValid

```solidity
error Rebalancer_RequestNotValid();
```

### Rebalancer_AddressNotValid

```solidity
error Rebalancer_AddressNotValid();
```

### Rebalancer_BridgeNotWhitelisted

```solidity
error Rebalancer_BridgeNotWhitelisted();
```

### Rebalancer_TransferSizeExcedeed

```solidity
error Rebalancer_TransferSizeExcedeed();
```

### Rebalancer_TransferSizeMinNotMet

```solidity
error Rebalancer_TransferSizeMinNotMet();
```

### Rebalancer_DestinationNotWhitelisted

```solidity
error Rebalancer_DestinationNotWhitelisted();
```

## Structs
### Msg

```solidity
struct Msg {
    uint32 dstChainId;
    address token;
    bytes message;
    bytes bridgeData;
}
```

