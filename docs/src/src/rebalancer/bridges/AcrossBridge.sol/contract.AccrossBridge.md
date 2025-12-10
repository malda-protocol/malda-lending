# AccrossBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/rebalancer/bridges/AcrossBridge.sol)

**Inherits:**
[BaseBridge](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/rebalancer/bridges/BaseBridge.sol/abstract.BaseBridge.md), [IBridge](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/IBridge.sol/interface.IBridge.md), [IAcrossReceiverV3](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/external/across/IAcrossReceiverV3.sol/interface.IAcrossReceiverV3.md), ReentrancyGuard

**Author:**
Merge Layers Inc.

Bridge integration for Across V3 used by the rebalancer


## State Variables
### SLIPPAGE_PRECISION
Precision used for slippage calculations


```solidity
uint256 private constant SLIPPAGE_PRECISION = 1e5
```


### ACROSS_SPOKE_POOL
Across spoke pool address


```solidity
address public immutable ACROSS_SPOKE_POOL
```


### MAX_SLIPPAGE
Maximum allowed slippage in basis points


```solidity
uint256 public immutable MAX_SLIPPAGE
```


### REBALANCER
Rebalancer contract address


```solidity
address public immutable REBALANCER
```


### whitelistedRelayers
Whitelisted relayers per destination chain


```solidity
mapping(uint32 dstChainId => mapping(address relayer => bool isWhitelisted)) public whitelistedRelayers
```


## Functions
### onlySpokePool

Modifier to restrict access to only the spoke pool


```solidity
modifier onlySpokePool() ;
```

### constructor

Initializes the Across bridge


```solidity
constructor(address _roles, address _spokePool, address _rebalancer) BaseBridge(_roles);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|Address of the roles contract|
|`_spokePool`|`address`|Address of the Across spoke pool|
|`_rebalancer`|`address`|Address of the rebalancer contract|


### setWhitelistedRelayer

Whitelists or removes a relayer for a destination chain


```solidity
function setWhitelistedRelayer(uint32 _dstId, address _relayer, bool status) external onlyBridgeConfigurator;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstId`|`uint32`|The destination chain ID|
|`_relayer`|`address`|The relayer address to update|
|`status`|`bool`|Whether the relayer is whitelisted|


### handleV3AcrossMessage

handles AcrossV3 SpokePool message


```solidity
function handleV3AcrossMessage(
    address tokenSent,
    uint256 amount,
    address, /* relayer is unused */
    bytes calldata message
)
    external
    onlySpokePool
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenSent`|`address`|the token address received|
|`amount`|`uint256`|the token amount|
|`<none>`|`address`||
|`message`|`bytes`|the custom message sent from source|


### sendMsg

rebalance through bridge


```solidity
function sendMsg(
    uint256 _extractedAmount,
    address _market,
    uint32 _dstChainId,
    address _token,
    bytes calldata _message,
    bytes calldata /* _bridgeData */
) external payable onlyRebalancer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_extractedAmount`|`uint256`|extracted amount for rebalancing|
|`_market`|`address`|destination address|
|`_dstChainId`|`uint32`|destination chain id|
|`_token`|`address`|the token to rebalance|
|`_message`|`bytes`|operation message data|
|`<none>`|`bytes`||


### isRelayerWhitelisted

Returns whether an address is whitelisted as relayer for a destination chain


```solidity
function isRelayerWhitelisted(uint32 dstChain, address relayer) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChain`|`uint32`|The destination chain ID|
|`relayer`|`address`|The relayer address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isWhitelisted True if relayer is whitelisted|


### getFee

computes fee for bridge operation


```solidity
function getFee(
    uint32,
    /* _dstChainId */
    bytes calldata,
    /* _message */
    bytes calldata /* _bridgeData */
)
    external
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`||
|`<none>`|`bytes`||
|`<none>`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|fee Computed bridge fee|


### _depositV3Now

Deposits funds into Across spoke pool for immediate relay


```solidity
function _depositV3Now(bytes calldata _message, address _token, uint32 _dstChainId, address _market) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_message`|`bytes`|Encoded Across message|
|`_token`|`address`|Token being transferred|
|`_dstChainId`|`uint32`|Destination chain ID|
|`_market`|`address`|Market address encoded in the message|


### _decodeMessage

Decodes the Across message payload


```solidity
function _decodeMessage(bytes calldata _message) private pure returns (DecodedMessage memory messageData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_message`|`bytes`|Encoded message data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`messageData`|`DecodedMessage`|The decoded message struct|


## Events
### Rebalanced
Emitted when funds are rebalanced to a market


```solidity
event Rebalanced(address indexed market, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|The market receiving funds|
|`amount`|`uint256`|The amount rebalanced|

### WhitelistedRelayerStatusUpdated
Emitted when relayer whitelist status is updated


```solidity
event WhitelistedRelayerStatusUpdated(
    address indexed sender, uint32 indexed dstId, address indexed delegate, bool status
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The caller updating whitelist|
|`dstId`|`uint32`|The destination chain ID|
|`delegate`|`address`|The relayer address|
|`status`|`bool`|The whitelist status|

## Errors
### AcrossBridge_TokenMismatch
Error thrown when tokens do not match expected underlying


```solidity
error AcrossBridge_TokenMismatch();
```

### AcrossBridge_NotAuthorized
Error thrown when caller is not authorized


```solidity
error AcrossBridge_NotAuthorized();
```

### AcrossBridge_NotImplemented
Error thrown when feature is not implemented


```solidity
error AcrossBridge_NotImplemented();
```

### AcrossBridge_AddressNotValid
Error thrown when an address is not valid


```solidity
error AcrossBridge_AddressNotValid();
```

### AcrossBridge_SlippageNotValid
Error thrown when slippage exceeds maximum


```solidity
error AcrossBridge_SlippageNotValid();
```

### AcrossBridge_RelayerNotValid
Error thrown when relayer is not valid


```solidity
error AcrossBridge_RelayerNotValid();
```

### AcrossBridge_InvalidReceiver
Error thrown when receiver market is invalid


```solidity
error AcrossBridge_InvalidReceiver();
```

### AcrossBridge_MaxFeeExceeded
Error thrown when relayer fee exceeds maximum


```solidity
error AcrossBridge_MaxFeeExceeded();
```

## Structs
### DecodedMessage
Decoded Across message payload


```solidity
struct DecodedMessage {
    address outputToken;
    uint256 inputAmount;
    uint256 outputAmount;
    address relayer;
    uint32 deadline;
    uint32 exclusivityDeadline;
}
```

