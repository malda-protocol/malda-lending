# EverclearBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\rebalancer\bridges\EverclearBridge.sol)

**Inherits:**
[BaseBridge](/src\rebalancer\bridges\BaseBridge.sol\abstract.BaseBridge.md), [IBridge](/src\interfaces\IBridge.sol\interface.IBridge.md)


## State Variables
### everclearSpoke

```solidity
IEverclearSpoke public everclearSpoke;
```


## Functions
### constructor


```solidity
constructor(address _roles, address _spoke) BaseBridge(_roles);
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


## Events
### MsgSent

```solidity
event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);
```

## Errors
### Everclear_NotImplemented

```solidity
error Everclear_NotImplemented();
```

### Everclear_AddressNotValid

```solidity
error Everclear_AddressNotValid();
```

