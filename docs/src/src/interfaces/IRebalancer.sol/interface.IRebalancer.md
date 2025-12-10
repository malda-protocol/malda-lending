# IRebalancer
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/interfaces/IRebalancer.sol)

**Author:**
Merge Layers Inc.

Interface for rebalancer operations and configuration


## Functions
### sendMsg

Sends a bridge message


```solidity
function sendMsg(address bridge, address _market, uint256 _amount, Msg calldata _msg) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|The whitelisted bridge address|
|`_market`|`address`|The market to rebalance from address|
|`_amount`|`uint256`|The amount to rebalance|
|`_msg`|`Msg`|The message data|


### nonce

Returns current nonce


```solidity
function nonce() external view returns (uint256 currentNonce);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currentNonce`|`uint256`|Nonce value|


### isBridgeWhitelisted

Returns if a bridge implementation is whitelisted


```solidity
function isBridgeWhitelisted(address bridge) external view returns (bool whitelisted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|Bridge address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`whitelisted`|`bool`|True if whitelisted|


### isDestinationWhitelisted

Returns if a destination is whitelisted


```solidity
function isDestinationWhitelisted(uint32 dstId) external view returns (bool whitelisted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstId`|`uint32`|Destination chain ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`whitelisted`|`bool`|True if whitelisted|


### isMarketWhitelisted

Returns if a market is whitelisted


```solidity
function isMarketWhitelisted(address market) external view returns (bool whitelisted);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|Market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`whitelisted`|`bool`|True if whitelisted|


## Events
### BridgeWhitelistedStatusUpdated
Emitted when bridge whitelist status changes


```solidity
event BridgeWhitelistedStatusUpdated(address indexed bridge, bool status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|Bridge address|
|`status`|`bool`|Whitelist status|

### MsgSent
Emitted when a message is sent through a bridge


```solidity
event MsgSent(
    address indexed bridge, uint32 indexed dstChainId, address indexed token, bytes message, bytes bridgeData
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|Bridge address|
|`dstChainId`|`uint32`|Destination chain ID|
|`token`|`address`|Token address|
|`message`|`bytes`|Encoded message|
|`bridgeData`|`bytes`|Bridge-specific data|

### EthSaved
Emitted when ETH is saved back to treasury


```solidity
event EthSaved(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount saved|

### MaxTransferSizeUpdated
Emitted when max transfer size is updated


```solidity
event MaxTransferSizeUpdated(uint32 indexed dstChainId, address indexed token, uint256 newLimit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|Destination chain ID|
|`token`|`address`|Token address|
|`newLimit`|`uint256`|New limit|

### MinTransferSizeUpdated
Emitted when min transfer size is updated


```solidity
event MinTransferSizeUpdated(uint32 indexed dstChainId, address indexed token, uint256 newLimit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|Destination chain ID|
|`token`|`address`|Token address|
|`newLimit`|`uint256`|New limit|

### DestinationWhitelistedStatusUpdated
Emitted when destination whitelist status changes


```solidity
event DestinationWhitelistedStatusUpdated(uint32 indexed dstChainId, bool status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|Destination chain ID|
|`status`|`bool`|Whitelist status|

### AllowedListUpdated
Emitted when allowed list is updated


```solidity
event AllowedListUpdated(address[] list, bool status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`list`|`address[]`|List of addresses|
|`status`|`bool`|Whitelist status|

### TokensSaved
Emitted when tokens are rescued


```solidity
event TokensSaved(address indexed token, address indexed market, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address|
|`market`|`address`|Market address|
|`amount`|`uint256`|Amount saved|

### AllowedTokensUpdated
Emitted when allowed tokens list is updated for a bridge


```solidity
event AllowedTokensUpdated(address indexed bridge, bool status, address[] list);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|Bridge address|
|`status`|`bool`|Whitelist status|
|`list`|`address[]`|Token list|

### MarketListUpdated
Emitted when market list is updated


```solidity
event MarketListUpdated(address[] list, bool status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`list`|`address[]`|Market list|
|`status`|`bool`|Whitelist status|

## Errors
### Rebalancer_NotAuthorized
Error thrown when caller not authorized


```solidity
error Rebalancer_NotAuthorized();
```

### Rebalancer_MarketNotValid
Error thrown when market is not valid


```solidity
error Rebalancer_MarketNotValid();
```

### Rebalancer_RequestNotValid
Error thrown when request is not valid


```solidity
error Rebalancer_RequestNotValid();
```

### Rebalancer_AddressNotValid
Error thrown when address is not valid


```solidity
error Rebalancer_AddressNotValid();
```

### Rebalancer_BridgeNotWhitelisted
Error thrown when bridge is not whitelisted


```solidity
error Rebalancer_BridgeNotWhitelisted();
```

### Rebalancer_TransferSizeExcedeed
Error thrown when transfer size exceeds maximum


```solidity
error Rebalancer_TransferSizeExcedeed();
```

### Rebalancer_TransferSizeMinNotMet
Error thrown when transfer size below minimum


```solidity
error Rebalancer_TransferSizeMinNotMet();
```

### Rebalancer_DestinationNotWhitelisted
Error thrown when destination not whitelisted


```solidity
error Rebalancer_DestinationNotWhitelisted();
```

### Rebalancer_UnderlyingNotAllowedForBridge
Error thrown when underlying token not allowed for bridge


```solidity
error Rebalancer_UnderlyingNotAllowedForBridge();
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

