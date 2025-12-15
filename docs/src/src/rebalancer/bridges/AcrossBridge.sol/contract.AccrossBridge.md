# AccrossBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\rebalancer\bridges\AcrossBridge.sol)

**Inherits:**
[BaseBridge](/src\rebalancer\bridges\BaseBridge.sol\abstract.BaseBridge.md), [IBridge](/src\interfaces\IBridge.sol\interface.IBridge.md), ReentrancyGuard


## State Variables
### acrossSpokePool

```solidity
address public immutable acrossSpokePool;
```


### maxSlippage

```solidity
uint256 public immutable maxSlippage;
```


### whitelistedRelayers

```solidity
mapping(uint32 => mapping(address => bool)) public whitelistedRelayers;
```


### SLIPPAGE_PRECISION

```solidity
uint256 private constant SLIPPAGE_PRECISION = 1e5;
```


## Functions
### constructor


```solidity
constructor(address _roles, address _spokePool) BaseBridge(_roles);
```

### onlySpokePool


```solidity
modifier onlySpokePool();
```

### setWhitelistedRelayer

Whitelists a delegate address


```solidity
function setWhitelistedRelayer(uint32 _dstId, address _relayer, bool status) external onlyBridgeConfigurator;
```

### getFee

computes fee for bridge operation


```solidity
function getFee(uint32, bytes memory, bytes memory) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`||
|`<none>`|`bytes`||
|`<none>`|`bytes`||


### isRelayerWhitelisted

returns if an address represents a whitelisted delegates


```solidity
function isRelayerWhitelisted(uint32 dstChain, address relayer) external view returns (bool);
```

### sendMsg

rebalance through bridge


```solidity
function sendMsg(
    uint256 _extractedAmount,
    address _market,
    uint32 _dstChainId,
    address _token,
    bytes memory _message,
    bytes memory
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


### handleV3AcrossMessage

handles AcrossV3 SpokePool message


```solidity
function handleV3AcrossMessage(address tokenSent, uint256 amount, address, bytes memory message)
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


### _decodeMessage


```solidity
function _decodeMessage(bytes memory _message) private pure returns (DecodedMessage memory);
```

### _depositV3Now


```solidity
function _depositV3Now(bytes memory _message, address _token, uint32 _dstChainId, address _market) private;
```

## Events
### Rebalanced

```solidity
event Rebalanced(address indexed market, uint256 amount);
```

### WhitelistedRelayerStatusUpdated

```solidity
event WhitelistedRelayerStatusUpdated(
    address indexed sender, uint32 indexed dstId, address indexed delegate, bool status
);
```

## Errors
### AcrossBridge_TokenMismatch

```solidity
error AcrossBridge_TokenMismatch();
```

### AcrossBridge_NotAuthorized

```solidity
error AcrossBridge_NotAuthorized();
```

### AcrossBridge_NotImplemented

```solidity
error AcrossBridge_NotImplemented();
```

### AcrossBridge_AddressNotValid

```solidity
error AcrossBridge_AddressNotValid();
```

### AcrossBridge_SlippageNotValid

```solidity
error AcrossBridge_SlippageNotValid();
```

### AcrossBridge_RelayerNotValid

```solidity
error AcrossBridge_RelayerNotValid();
```

## Structs
### DecodedMessage

```solidity
struct DecodedMessage {
    uint256 inputAmount;
    uint256 outputAmount;
    address relayer;
    uint32 deadline;
    uint32 exclusivityDeadline;
}
```

