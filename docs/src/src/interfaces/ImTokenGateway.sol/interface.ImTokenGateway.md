# ImTokenGateway
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\interfaces\ImTokenGateway.sol)


## Functions
### rolesOperator

Roles manager


```solidity
function rolesOperator() external view returns (IRoles);
```

### logsOperator

Logs manager


```solidity
function logsOperator() external view returns (ImTokenLogs);
```

### underlying

Returns the address of the underlying token


```solidity
function underlying() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the underlying token|


### isPaused

returns pause state for operation


```solidity
function isPaused(ImTokenOperationTypes.OperationType _type) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`ImTokenOperationTypes.OperationType`|the operation type|


### nonce

Returns nonce


```solidity
function nonce() external view returns (uint32);
```

### accAmountIn

Returns accumulated amount in per user


```solidity
function accAmountIn(address user) external view returns (uint256);
```

### accAmountOut

Returns accumulated amount out per user


```solidity
function accAmountOut(address user) external view returns (uint256);
```

### setPaused

Set pause for a specific operation


```solidity
function setPaused(ImTokenOperationTypes.OperationType _type, bool state) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`ImTokenOperationTypes.OperationType`|The pause operation type|
|`state`|`bool`|The pause operation status|


### supplyOnHost

Supply underlying to the contractr


```solidity
function supplyOnHost(uint256 amount, address user, address[] calldata allowedCallers) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The supplied amount|
|`user`|`address`|The user to supply for|
|`allowedCallers`|`address[]`|The allowed callers for host chain interactions|


### outOnHost

Supply underlying to the contractr


```solidity
function outOnHost(uint256 amount, address user, address[] calldata allowedCallers) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The supplied amount|
|`user`|`address`|The user to supply for|
|`allowedCallers`|`address[]`|The allowed callers for host chain interactions|


### outHere

Extract tokens


```solidity
function outHere(bytes calldata journalData, bytes calldata seal, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The supplied journal|
|`seal`|`bytes`|The seal address|
|`amount`|`uint256`|The amount to use|


## Events
### mTokenGateway_Supplied
Emitted when a supply operation is initiated


```solidity
event mTokenGateway_Supplied(
    address indexed from,
    address indexed user,
    uint256 amount,
    int32 srcNonce,
    int32 dstNonce,
    uint256 accAmountIn,
    uint32 srcChainId,
    uint32 dstChainId
);
```

### mTokenGateway_OutOnHost
Emitted when a supply operation is initiated


```solidity
event mTokenGateway_OutOnHost(
    address indexed from,
    address indexed user,
    uint256 amount,
    int32 srcNonce,
    int32 dstNonce,
    uint256 accAmountIn,
    uint32 srcChainId,
    uint32 dstChainId
);
```

### mTokenGateway_Extracted
Emitted when an extract was finalized


```solidity
event mTokenGateway_Extracted(
    address indexed msgSender,
    address indexed srcSender,
    address indexed srcUser,
    uint256 amount,
    int32 srcNonce,
    int32 dstNonce,
    uint256 accAmountOut,
    uint32 srcChainId,
    uint32 dstChainId
);
```

## Errors
### mTokenGateway_AddressNotValid
Thrown when the address is not valid


```solidity
error mTokenGateway_AddressNotValid();
```

### mTokenGateway_AmountNotValid
Thrown when the amount specified is invalid (e.g., zero)


```solidity
error mTokenGateway_AmountNotValid();
```

### mTokenGateway_JournalNotValid
Thrown when the journal data provided is invalid


```solidity
error mTokenGateway_JournalNotValid();
```

### mTokenGateway_AmountTooBig
Thrown when there is insufficient cash to release the specified amount


```solidity
error mTokenGateway_AmountTooBig();
```

### mTokenGateway_ReleaseCashNotAvailable
Thrown when there is insufficient cash to release the specified amount


```solidity
error mTokenGateway_ReleaseCashNotAvailable();
```

### mTokenGateway_NonTransferable
Thrown when token is tranferred


```solidity
error mTokenGateway_NonTransferable();
```

### mTokenGateway_CallerNotAllowed
Thrown when caller is not allowed


```solidity
error mTokenGateway_CallerNotAllowed();
```

### mTokenGateway_Paused
Thrown when market is paused for operation type


```solidity
error mTokenGateway_Paused(ImTokenOperationTypes.OperationType _type);
```

