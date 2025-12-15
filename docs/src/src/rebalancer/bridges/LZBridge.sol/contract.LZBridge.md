# LZBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/076616677457911e7c8925ff7d5fe2dec2ca1497/src\rebalancer\bridges\LZBridge.sol)

**Inherits:**
[BaseBridge](/src\rebalancer\bridges\BaseBridge.sol\abstract.BaseBridge.md), [IBridge](/src\interfaces\IBridge.sol\interface.IBridge.md)


## Functions
### constructor


```solidity
constructor(address _roles) BaseBridge(_roles);
```

### getFee

computes fee for bridge operation

*use `getOptionsData` for `_bridgeData`*


```solidity
function getFee(uint32 _dstChainId, bytes memory _message, bytes memory _composeMsg) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstChainId`|`uint32`|destination chain id|
|`_message`|`bytes`|operation message data|
|`_composeMsg`|`bytes`||


### sendMsg

rebalance through bridge


```solidity
function sendMsg(
    uint256 _extractedAmount,
    address _market,
    uint32 _dstChainId,
    address _token,
    bytes memory _message,
    bytes memory _composeMsg
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
|`_composeMsg`|`bytes`||


### _getFee


```solidity
function _getFee(uint32 dstEid, bytes memory _message, bytes memory _composeMsg)
    private
    view
    returns (MessagingFee memory fees, SendParam memory lzSendParams);
```

## Events
### MsgSent

```solidity
event MsgSent(uint32 indexed dstChainId, address indexed market, uint256 amountLD, uint256 minAmountLD, bytes32 guid);
```

## Errors
### LZBridge_NotEnoughFees

```solidity
error LZBridge_NotEnoughFees();
```

### LZBridge_ChainNotRegistered

```solidity
error LZBridge_ChainNotRegistered();
```

### LZBridge_DestinationMismatch

```solidity
error LZBridge_DestinationMismatch();
```

