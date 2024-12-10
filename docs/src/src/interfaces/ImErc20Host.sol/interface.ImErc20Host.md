# ImErc20Host
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\interfaces\ImErc20Host.sol)


## Functions
### nonce

Returns nonce


```solidity
function nonce() external view returns (uint32);
```

### logsOperator

Logs manager


```solidity
function logsOperator() external view returns (ImTokenLogs);
```

### liquidateExternal

Mints tokens after external verification


```solidity
function liquidateExternal(bytes calldata journalData, bytes calldata seal, uint256 liquidateAmount, address collateral)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|
|`liquidateAmount`|`uint256`|The amount to liquidate|
|`collateral`|`address`|The collateral to seize|


### mintExternal

Mints tokens after external verification


```solidity
function mintExternal(bytes calldata journalData, bytes calldata seal, uint256 mintAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|
|`mintAmount`|`uint256`|The amount to mint|


### borrowExternal

Borrows tokens after external verification


```solidity
function borrowExternal(bytes calldata journalData, bytes calldata seal, uint256 borrowAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for borrowing|
|`seal`|`bytes`|The Zk proof seal|
|`borrowAmount`|`uint256`|The amount to borrow|


### repayExternal

Repays tokens after external verification


```solidity
function repayExternal(bytes calldata journalData, bytes calldata seal, uint256 repayAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for repayment|
|`seal`|`bytes`|The Zk proof seal|
|`repayAmount`|`uint256`|The amount to repay|


### withdrawExternal

Withdraws tokens after external verification


```solidity
function withdrawExternal(bytes calldata journalData, bytes calldata seal, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for withdrawing|
|`seal`|`bytes`|The Zk proof seal|
|`amount`|`uint256`|The amount to withdraw|


### withdrawOnExtension

Initiates a withdraw operation


```solidity
function withdrawOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to withdraw|
|`dstChainId`|`uint32`|The destination chain to recieve funds|
|`allowedCallers`|`address[]`|The allowed callers for destination chain finalization|


### borrowOnExtension

Initiates a withdraw operation


```solidity
function borrowOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to withdraw|
|`dstChainId`|`uint32`|The destination chain to recieve funds|
|`allowedCallers`|`address[]`|The allowed callers for destination chain finalization|


## Events
### mErc20Host_LiquidateExternal
Emitted when a liquidate operation is executed


```solidity
event mErc20Host_LiquidateExternal(
    address indexed liquidator, address indexed borrower, address indexed collateral, LiquidateData liquidateData
);
```

### mErc20Host_MintExternal
Emitted when a mint operation is executed


```solidity
event mErc20Host_MintExternal(
    address msgSender,
    address indexed srcSender,
    address indexed user,
    int32 srcNonce,
    int32 nonce,
    uint256 accAmount,
    uint32 srcChainId,
    uint32 chainId,
    uint256 amount
);
```

### mErc20Host_BorrowExternal
Emitted when a borrow operation is executed


```solidity
event mErc20Host_BorrowExternal(
    address msgSender,
    address indexed srcSender,
    address indexed user,
    int32 srcNonce,
    int32 nonce,
    uint256 accAmount,
    uint32 srcChainId,
    uint32 chainId,
    uint256 amount
);
```

### mErc20Host_RepayExternal
Emitted when a repay operation is executed


```solidity
event mErc20Host_RepayExternal(
    address msgSender,
    address indexed srcSender,
    address indexed user,
    int32 srcNonce,
    int32 nonce,
    uint256 accAmount,
    uint32 srcChainId,
    uint32 chainId,
    uint256 amount
);
```

### mErc20Host_WithdrawExternal
Emitted when a withdrawal is executed


```solidity
event mErc20Host_WithdrawExternal(
    address msgSender,
    address indexed srcSender,
    address indexed user,
    int32 srcNonce,
    int32 nonce,
    uint256 accAmount,
    uint32 srcChainId,
    uint32 chainId,
    uint256 amount
);
```

### mErc20Host_BorrowOnExternsionChain
Emitted when a borrow operation is triggered for an extension chain


```solidity
event mErc20Host_BorrowOnExternsionChain(
    address indexed from,
    address indexed user,
    int32 srcNonce,
    int32 dstNonce,
    uint256 accAmount,
    uint32 srcChainId,
    uint32 dstChainId,
    uint256 amount
);
```

### mErc20Host_WithdrawOnExtensionChain
Emitted when a withdraw operation is triggered for an extension chain


```solidity
event mErc20Host_WithdrawOnExtensionChain(
    address indexed from,
    address indexed user,
    int32 srcNonce,
    int32 dstNonce,
    uint256 accAmount,
    uint32 srcChainId,
    uint32 dstChainId,
    uint256 amount
);
```

## Errors
### mErc20Host_AmountTooBig
Thrown when the amount provided is bigger than the available amount`


```solidity
error mErc20Host_AmountTooBig();
```

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

### LiquidateData

```solidity
struct LiquidateData {
    address msgSender;
    int32 srcNonce;
    int32 nonce;
    uint256 accAmount;
    uint32 srcChainId;
    uint32 chainId;
    uint256 amount;
}
```

