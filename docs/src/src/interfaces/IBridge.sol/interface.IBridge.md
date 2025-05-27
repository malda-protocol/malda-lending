# IBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\interfaces\IBridge.sol)


## Functions
### getFee

computes fee for bridge operation


```solidity
function getFee(uint32 _dstChainId, bytes memory _message, bytes memory _bridgeData) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstChainId`|`uint32`|destination chain id|
|`_message`|`bytes`|operation message data|
|`_bridgeData`|`bytes`|specific bridge data|


### sendMsg

rebalance through bridge


```solidity
function sendMsg(
    uint256 _extractedAmount,
    address _market,
    uint32 _dstChainId,
    address _token,
    bytes memory _message,
    bytes memory _bridgeData
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


