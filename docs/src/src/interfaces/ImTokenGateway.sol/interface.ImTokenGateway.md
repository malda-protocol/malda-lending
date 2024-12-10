# ImTokenGateway
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\ImTokenGateway.sol)


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


### getNonce

Retrieves the current nonce for a user and operation type


```solidity
function getNonce(address user, uint32 chainId, ImTokenOperationTypes.OperationType opType)
    external
    view
    returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`chainId`|`uint32`|The chainId to get the data for|
|`opType`|`ImTokenOperationTypes.OperationType`|The operation type (Mint, Borrow, Repay, Withdraw, Release)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The current nonce for the specified user and operation type|


### nonces

Retrieves the current nonce for a user and a specific operation type


```solidity
function nonces(address user, uint32 chainId, ImTokenOperationTypes.OperationType opType)
    external
    view
    returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`chainId`|`uint32`|The chainId to get the data for|
|`opType`|`ImTokenOperationTypes.OperationType`|The operation type (Mint, Borrow, Repay, Withdraw, Release)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The nonce for the specified user and operation type|


### isPaused

returns pause state for operation


```solidity
function isPaused(ImTokenOperationTypes.OperationType _type) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`ImTokenOperationTypes.OperationType`|the operation type|


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


### liquidateOnHost

Initiates a liquidation request to be fulfilled on host

*`collateral` can be address(0)*


```solidity
function liquidateOnHost(uint256 amount, address user, address collateral) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to liquidate|
|`user`|`address`|The position to liquidate|
|`collateral`|`address`|The collateral to receive|


### mintOnHost

Mints new tokens by transferring the underlying token from the user


```solidity
function mintOnHost(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to mint|


### borrowOnHost

Initiates a borrowing operation


```solidity
function borrowOnHost(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to borrow|


### borrowExternal

Finalizes a borrow action initiated from host chain


```solidity
function borrowExternal(bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data containing the release information|
|`seal`|`bytes`|The zk-proof data required to verify the release|


### repayOnHost

Repays a borrowed amount by transferring the underlying token from the user


```solidity
function repayOnHost(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to repay|


### withdrawOnHost

Withdraws tokens and burns the corresponding minted tokens


```solidity
function withdrawOnHost(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to withdraw|


### withdrawExternal

Releases tokens to a user based on a validated zk-proof and journal data


```solidity
function withdrawExternal(bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data containing the release information|
|`seal`|`bytes`|The zk-proof data required to verify the release|


## Events
### mTokenGateway_LiquidateInitiated
Emitted when a liquidate operation is initiated


```solidity
event mTokenGateway_LiquidateInitiated(
    address indexed liquidator,
    address indexed user,
    address indexed collateral,
    uint256 amount,
    uint32 nonce,
    uint32 chainId
);
```

### mTokenGateway_MintInitiated
Emitted when a mint operation is initiated


```solidity
event mTokenGateway_MintInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);
```

### mTokenGateway_BorrowInitiated
Emitted when a borrow operation is initiated


```solidity
event mTokenGateway_BorrowInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);
```

### mTokenGateway_RepayInitiated
Emitted when a repay operation is initiated


```solidity
event mTokenGateway_RepayInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);
```

### mTokenGateway_WithdrawInitiated
Emitted when a withdrawal is initiated


```solidity
event mTokenGateway_WithdrawInitiated(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);
```

### mTokenGateway_Released
Emitted when a release operation is executed


```solidity
event mTokenGateway_Released(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);
```

### mTokenGateway_BorrowExternal
Emitted when a borrow operation is finalized


```solidity
event mTokenGateway_BorrowExternal(address indexed from, uint256 amount, uint32 nonce, uint32 chainId);
```

## Errors
### mTokenGateway_AddressNotValid
Thrown when the address is not valid


```solidity
error mTokenGateway_AddressNotValid();
```

### mTokenGateway_AmountTooBig
Thrown when the amount specified is too large for the operation


```solidity
error mTokenGateway_AmountTooBig();
```

### mTokenGateway_NonceNotValid
Thrown when the nonce provided is invalid for the operation


```solidity
error mTokenGateway_NonceNotValid();
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

