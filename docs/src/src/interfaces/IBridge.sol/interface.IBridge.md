# IBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/IBridge.sol)

**Title:**
IBridge

**Author:**
Merge Layers Inc.

Interface for rebalancing bridge implementations


## Functions
### sendMsg

rebalance through bridge


```solidity
function sendMsg(
    uint256 _extractedAmount,
    address _market,
    uint32 _dstChainId,
    address _token,
    bytes calldata _message,
    bytes calldata _bridgeData
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_extractedAmount`|`uint256`|extracted amount for rebalancing|
|`_market`|`address`|destination address|
|`_dstChainId`|`uint32`|destination chain id|
|`_token`|`address`|the token to rebalance|
|`_message`|`bytes`|operation message data|
|`_bridgeData`|`bytes`|specific bridge datas|


### getFee

computes fee for bridge operation


```solidity
function getFee(uint32 _dstChainId, bytes calldata _message, bytes calldata _bridgeData)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstChainId`|`uint32`|destination chain id|
|`_message`|`bytes`|operation message data|
|`_bridgeData`|`bytes`|specific bridge data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|fee Computed bridge fee|


