# mTokenLogs
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\mToken\mTokenLogs.sol)

**Inherits:**
[ImTokenLogs](/src\interfaces\ImTokenLogs.sol\interface.ImTokenLogs.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## State Variables
### roles

```solidity
IRoles public roles;
```


### journals

```solidity
mapping(address => mapping(uint256 => mapping(OperationType => mapping(uint256 => LogData)))) public journals;
```


## Functions
### constructor


```solidity
constructor(address _roles);
```

### getLog

returns registered journal for a specific chain


```solidity
function getLog(address user, OperationType opType, uint32 nonce)
    external
    view
    override
    returns (uint32 chainId, bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|the account address|
|`opType`|`OperationType`|the operation type|
|`nonce`|`uint32`|the nonce value|


### getLogForChain

returns registered journal for a specific chain


```solidity
function getLogForChain(address user, OperationType opType, uint32 nonce, uint32 chainId)
    external
    view
    override
    returns (uint32, bytes memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|the account address|
|`opType`|`OperationType`|the operation type|
|`nonce`|`uint32`|the nonce value|
|`chainId`|`uint32`|the source chain id type|


### registerLog

registers a journal data


```solidity
function registerLog(
    address user,
    OperationType opType,
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
|`opType`|`OperationType`|the operation type|
|`srcChainId`|`uint32`|the source chain id type|
|`dstChainId`|`uint32`|the destination chain id type|
|`nonce`|`uint32`|the nonce value|
|`data`|`bytes`|the encoded journal data|


