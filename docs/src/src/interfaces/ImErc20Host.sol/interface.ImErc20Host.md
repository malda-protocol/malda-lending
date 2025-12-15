# ImErc20Host
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\ImErc20Host.sol)


## Functions
### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32 dstId) external view returns (uint256, uint256);
```

### mintOrBorrowMigration

Mints mTokens during migration without requiring underlying transfer


```solidity
function mintOrBorrowMigration(bool mint, uint256 amount, address receiver, address borrower, uint256 minAmount)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mint`|`bool`|Mint or borrow|
|`amount`|`uint256`|The amount of underlying to be accounted for|
|`receiver`|`address`|The address that will receive the mTokens or the underlying in case of borrowing|
|`borrower`|`address`|The address that borrow is executed for|
|`minAmount`|`uint256`|The min amount of underlying to be accounted for|


### extractForRebalancing

Extract amount to be used for rebalancing operation


```solidity
function extractForRebalancing(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to rebalance|


### updateAllowedCallerStatus

Set caller status for `msg.sender`


```solidity
function updateAllowedCallerStatus(address caller, bool status) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The caller address|
|`status`|`bool`|The status to set for `caller`|


### liquidateExternal

Mints tokens after external verification


```solidity
function liquidateExternal(
    bytes calldata journalData,
    bytes calldata seal,
    address[] calldata userToLiquidate,
    uint256[] calldata liquidateAmount,
    address[] calldata collateral,
    address receiver
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting (array of encoded journals)|
|`seal`|`bytes`|The Zk proof seal|
|`userToLiquidate`|`address[]`|Array of positions to liquidate|
|`liquidateAmount`|`uint256[]`|Array of amounts to liquidate|
|`collateral`|`address[]`|Array of collaterals to seize|
|`receiver`|`address`|The collateral receiver|


### mintExternal

Mints tokens after external verification


```solidity
function mintExternal(
    bytes calldata journalData,
    bytes calldata seal,
    uint256[] calldata mintAmount,
    uint256[] calldata minAmountsOut,
    address receiver
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting (array of encoded journals)|
|`seal`|`bytes`|The Zk proof seal|
|`mintAmount`|`uint256[]`|Array of amounts to mint|
|`minAmountsOut`|`uint256[]`|Array of min amounts accepted|
|`receiver`|`address`|The tokens receiver|


### repayExternal

Repays tokens after external verification


```solidity
function repayExternal(
    bytes calldata journalData,
    bytes calldata seal,
    uint256[] calldata repayAmount,
    address receiver
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for repayment (array of encoded journals)|
|`seal`|`bytes`|The Zk proof seal|
|`repayAmount`|`uint256[]`|Array of amounts to repay|
|`receiver`|`address`|The position to repay for|


### performExtensionCall

Initiates a withdraw operation


```solidity
function performExtensionCall(uint256 actionType, uint256 amount, uint32 dstChainId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionType`|`uint256`|The actionType param (1 - withdraw, 2 - borrow)|
|`amount`|`uint256`|The amount to withdraw|
|`dstChainId`|`uint32`|The destination chain to recieve funds|


## Events
### AllowedCallerUpdated
Emitted when a user updates allowed callers


```solidity
event AllowedCallerUpdated(address indexed sender, address indexed caller, bool status);
```

### mErc20Host_ChainStatusUpdated
Emitted when a chain id whitelist status is updated


```solidity
event mErc20Host_ChainStatusUpdated(uint32 indexed chainId, bool status);
```

### mErc20Host_LiquidateExternal
Emitted when a liquidate operation is executed


```solidity
event mErc20Host_LiquidateExternal(
    address indexed msgSender,
    address indexed srcSender,
    address userToLiquidate,
    address receiver,
    address indexed collateral,
    uint32 srcChainId,
    uint256 amount
);
```

### mErc20Host_MintExternal
Emitted when a mint operation is executed


```solidity
event mErc20Host_MintExternal(
    address indexed msgSender, address indexed srcSender, address indexed receiver, uint32 chainId, uint256 amount
);
```

### mErc20Host_BorrowExternal
Emitted when a borrow operation is executed


```solidity
event mErc20Host_BorrowExternal(
    address indexed msgSender, address indexed srcSender, uint32 indexed chainId, uint256 amount
);
```

### mErc20Host_RepayExternal
Emitted when a repay operation is executed


```solidity
event mErc20Host_RepayExternal(
    address indexed msgSender, address indexed srcSender, address indexed position, uint32 chainId, uint256 amount
);
```

### mErc20Host_WithdrawExternal
Emitted when a withdrawal is executed


```solidity
event mErc20Host_WithdrawExternal(
    address indexed msgSender, address indexed srcSender, uint32 indexed chainId, uint256 amount
);
```

### mErc20Host_BorrowOnExtensionChain
Emitted when a borrow operation is triggered for an extension chain


```solidity
event mErc20Host_BorrowOnExtensionChain(address indexed sender, uint32 dstChainId, uint256 amount);
```

### mErc20Host_WithdrawOnExtensionChain
Emitted when a withdraw operation is triggered for an extension chain


```solidity
event mErc20Host_WithdrawOnExtensionChain(address indexed sender, uint32 dstChainId, uint256 amount);
```

### mErc20Host_GasFeeUpdated
Emitted when gas fees are updated for a dst chain


```solidity
event mErc20Host_GasFeeUpdated(uint32 indexed dstChainId, uint256 amount);
```

### mErc20Host_MintMigration

```solidity
event mErc20Host_MintMigration(address indexed receiver, uint256 amount);
```

### mErc20Host_BorrowMigration

```solidity
event mErc20Host_BorrowMigration(address indexed borrower, uint256 amount);
```

## Errors
### mErc20Host_ProofGenerationInputNotValid
Thrown when the chain id is not LINEA


```solidity
error mErc20Host_ProofGenerationInputNotValid();
```

### mErc20Host_DstChainNotValid
Thrown when the dst chain id is not current chain


```solidity
error mErc20Host_DstChainNotValid();
```

### mErc20Host_ChainNotValid
Thrown when the chain id is not LINEA


```solidity
error mErc20Host_ChainNotValid();
```

### mErc20Host_AddressNotValid
Thrown when the address is not valid


```solidity
error mErc20Host_AddressNotValid();
```

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

### mErc20Host_NotRebalancer
Thrown when caller is not rebalancer


```solidity
error mErc20Host_NotRebalancer();
```

### mErc20Host_LengthMismatch
Thrown when length of array is not valid


```solidity
error mErc20Host_LengthMismatch();
```

### mErc20Host_NotEnoughGasFee
Thrown when not enough gas fee was received


```solidity
error mErc20Host_NotEnoughGasFee();
```

### mErc20Host_L1InclusionRequired
Thrown when L1 inclusion is required


```solidity
error mErc20Host_L1InclusionRequired();
```

### mErc20Host_ActionNotAvailable
Thrown when extension action is not valid


```solidity
error mErc20Host_ActionNotAvailable();
```

