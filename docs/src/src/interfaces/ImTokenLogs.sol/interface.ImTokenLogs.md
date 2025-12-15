# ImTokenLogs
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\interfaces\ImTokenLogs.sol)


## Functions
### getLog

returns registered journal for a specific chain


```solidity
function getLog(address user, ImTokenOperationTypes.OperationType opType, uint32 nonce)
    external
    view
    returns (uint32 dstChainId, bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|the account address|
|`opType`|`ImTokenOperationTypes.OperationType`|the operation type|
|`nonce`|`uint32`|the nonce value|


### getLogForChain

returns registered journal for a specific chain


```solidity
function getLogForChain(address user, ImTokenOperationTypes.OperationType opType, uint32 nonce, uint32 chainId)
    external
    view
    returns (uint32 dstChainId, bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|the account address|
|`opType`|`ImTokenOperationTypes.OperationType`|the operation type|
|`nonce`|`uint32`|the nonce value|
|`chainId`|`uint32`|the source chain id type|


### registerLog

registers a journal data


```solidity
function registerLog(
    address user,
    ImTokenOperationTypes.OperationType opType,
    uint32 srcChainId,
    uint32 dstChainId,
    uint32 nonce,
    bytes memory data
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|the account address|
|`opType`|`ImTokenOperationTypes.OperationType`|the operation type|
|`srcChainId`|`uint32`|the source chain id type|
|`dstChainId`|`uint32`|the destination chain id type|
|`nonce`|`uint32`|the nonce value|
|`data`|`bytes`|the encoded journal data|


## Events
### JournalRegistered

```solidity
event JournalRegistered(
    address indexed user, ImTokenOperationTypes.OperationType opType, uint32 nonce, uint32 srcChainId, uint32 dstChainId
);
```

## Errors
### mTokenLogs_NotAllowed

```solidity
error mTokenLogs_NotAllowed();
```

### mTokenLogs_AddressNotValid

```solidity
error mTokenLogs_AddressNotValid();
```

## Structs
### LogData

```solidity
struct LogData {
    uint32 chainId;
    bytes data;
}
```

