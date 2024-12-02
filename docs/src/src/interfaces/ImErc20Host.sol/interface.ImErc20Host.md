# ImErc20Host
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\ImErc20Host.sol)


## Functions
### logsOperator

Logs manager


```solidity
function logsOperator() external view returns (ImTokenLogs);
```

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
|`opType`|`ImTokenOperationTypes.OperationType`|The operation type (Mint, Borrow, Repay, Redeem)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The current nonce for the specified user and operation type|


### liquidateExternal

Mints tokens after external verification


```solidity
function liquidateExternal(bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|


### mintExternal

Mints tokens after external verification


```solidity
function mintExternal(bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|


### borrowExternal

Borrows tokens after external verification


```solidity
function borrowExternal(bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for borrowing|
|`seal`|`bytes`|The Zk proof seal|


### borrowOnExtension

Initiates a borrowing operation


```solidity
function borrowOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to borrow|
|`journalData`|`bytes`|The journal data for borrowing|
|`seal`|`bytes`|The Zk proof seal|


### repayExternal

Repays tokens after external verification


```solidity
function repayExternal(bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for repayment|
|`seal`|`bytes`|The Zk proof seal|


### withdrawExternal

Withdraws tokens after external verification


```solidity
function withdrawExternal(bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for withdrawing|
|`seal`|`bytes`|The Zk proof seal|


### withdrawOnExtension

Initiates a withdraw operation


```solidity
function withdrawOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`||
|`journalData`|`bytes`|The journal data for withdrawing|
|`seal`|`bytes`|The Zk proof seal|


## Events
### mErc20Host_LiquidateExternal
Emitted when a liquidate operation is executed


```solidity
event mErc20Host_LiquidateExternal(
    address indexed liquidator,
    address indexed user,
    address indexed collateral,
    uint256 amount,
    uint32 nonce,
    uint32 chainId
);
```

### mErc20Host_MintExternal
Emitted when a mint operation is executed


```solidity
event mErc20Host_MintExternal(address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId);
```

### mErc20Host_BorrowExternal
Emitted when a borrow operation is executed


```solidity
event mErc20Host_BorrowExternal(
    address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
);
```

### mErc20Host_BorrowOnExternsionChain
Emitted when a borrow operation is triggered for an extension chain


```solidity
event mErc20Host_BorrowOnExternsionChain(
    address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
);
```

### mErc20Host_RepayExternal
Emitted when a repay operation is executed


```solidity
event mErc20Host_RepayExternal(
    address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
);
```

### mErc20Host_WithdrawExternal
Emitted when a withdrawal is executed


```solidity
event mErc20Host_WithdrawExternal(
    address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
);
```

### mErc20Host_WithdrawOnExtensionChain
Emitted when a withdraw operation is triggered for an extension chain


```solidity
event mErc20Host_WithdrawOnExtensionChain(
    address indexed from, address indexed user, uint256 amount, uint32 nonce, uint32 chainId
);
```

## Errors
### mErc20Host_AmountNotValid
Thrown when the amount specified is invalid (e.g., zero)


```solidity
error mErc20Host_AmountNotValid();
```

### mErc20Host_JournalNotValid
Thrown when the journal data provided is invalid or corrupted


```solidity
error mErc20Host_JournalNotValid();
```

### mErc20Host_NonceNotValid
Thrown when the nonce provided is invalid or does not match the expected value


```solidity
error mErc20Host_NonceNotValid();
```

### mErc20Host_CallerNotAllowed
Thrown when caller is not allowed


```solidity
error mErc20Host_CallerNotAllowed();
```

## Structs
### InitData

```solidity
struct InitData {
    address underlyingToken;
    address operator;
    address interestModel;
    uint256 exchaneRateMantissa;
    string name;
    string symbol;
    uint8 decimals;
    address zkVerifier;
    address imageRegistry;
    address owner;
}
```

