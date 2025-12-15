# ConnextBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/076616677457911e7c8925ff7d5fe2dec2ca1497/src\rebalancer\bridges\ConnextBridge.sol)

**Inherits:**
[BaseBridge](/src\rebalancer\bridges\BaseBridge.sol\abstract.BaseBridge.md), [IBridge](/src\interfaces\IBridge.sol\interface.IBridge.md)


## State Variables
### connext

```solidity
IConnext public immutable connext;
```


### domainIds

```solidity
mapping(uint32 => uint32) public domainIds;
```


### whitelistedDelegates

```solidity
mapping(uint32 => mapping(address => bool)) public whitelistedDelegates;
```


## Functions
### constructor


```solidity
constructor(address _roles, address _connext) BaseBridge(_roles);
```

### setDomainId

Set domain id


```solidity
function setDomainId(uint32 _dstId, uint32 _domainId) external onlyBridgeConfigurator;
```

### setWhitelistedDelegate

Whitelists a delegate address


```solidity
function setWhitelistedDelegate(uint32 _dstId, address _delegate, bool status) external onlyBridgeConfigurator;
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


### isDelegateWhitelisted

returns if an address represents a whitelisted delegates


```solidity
function isDelegateWhitelisted(uint32 dstChain, address delegate) external view returns (bool);
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


### _decodeMessage


```solidity
function _decodeMessage(bytes memory _message) private pure returns (DecodedMessage memory);
```

## Events
### MsgSent

```solidity
event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, uint256 slippage, bytes32 id);
```

### DomainIdSet

```solidity
event DomainIdSet(uint32 indexed dstId, uint32 indexed domainId);
```

### WhitelistedDelegateStatusUpdated

```solidity
event WhitelistedDelegateStatusUpdated(
    address indexed sender, uint32 indexed dstId, address indexed delegate, bool status
);
```

## Errors
### Connext_NotEnoughFees

```solidity
error Connext_NotEnoughFees();
```

### Connext_NotImplemented

```solidity
error Connext_NotImplemented();
```

### Connext_DomainIdNotSet

```solidity
error Connext_DomainIdNotSet();
```

### Connext_DelegateNotValid

```solidity
error Connext_DelegateNotValid();
```

## Structs
### DecodedMessage

```solidity
struct DecodedMessage {
    address delegate;
    uint256 amount;
    uint256 slippage;
    uint256 relayerFee;
}
```

