# ImTokenGateway
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/ImTokenGateway.sol)

**Author:**
Merge Layers Inc.

Gateway interface for cross-chain mToken operations


## Functions
### extractForRebalancing

Extract amount to be used for rebalancing operation


```solidity
function extractForRebalancing(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to rebalance|


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


### supplyOnHost

Supply underlying to the contract


```solidity
function supplyOnHost(uint256 amount, address receiver, bytes4 lineaSelector) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The supplied amount|
|`receiver`|`address`|The receiver address|
|`lineaSelector`|`bytes4`|The method selector to be called on Linea by our relayer. If empty, user has to submit it|


### liquidate

Liquidate a user


```solidity
function liquidate(address userToLiquidate, uint256 liquidateAmount, address collateral, address receiver)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userToLiquidate`|`address`|The user to liquidate|
|`liquidateAmount`|`uint256`|The amount to liquidate|
|`collateral`|`address`|The collateral address|
|`receiver`|`address`|The receiver address|


### outHere

Extract tokens


```solidity
function outHere(bytes calldata journalData, bytes calldata seal, uint256[] memory amounts, address receiver)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The supplied journal|
|`seal`|`bytes`|The seal address|
|`amounts`|`uint256[]`|The amounts to withdraw for each journal|
|`receiver`|`address`|The receiver address|


### rolesOperator

Roles


```solidity
function rolesOperator() external view returns (IRoles roles);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`roles`|`IRoles`|Roles operator contract|


### blacklistOperator

Blacklist operator


```solidity
function blacklistOperator() external view returns (IBlacklister blacklister);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`blacklister`|`IBlacklister`|Blacklister contract|


### underlying

Returns the address of the underlying token


```solidity
function underlying() external view returns (address underlyingToken);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`underlyingToken`|`address`|The address of the underlying token|


### isPaused

Returns pause state for operation


```solidity
function isPaused(ImTokenOperationTypes.OperationType _type) external view returns (bool paused);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`ImTokenOperationTypes.OperationType`|The operation type|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`paused`|`bool`|True if paused|


### accAmountIn

Returns accumulated amount in per user


```solidity
function accAmountIn(address user) external view returns (uint256 amountIn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountIn`|`uint256`|Accumulated amount in|


### accAmountOut

Returns accumulated amount out per user


```solidity
function accAmountOut(address user) external view returns (uint256 amountOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountOut`|`uint256`|Accumulated amount out|


### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32 dstId) external view returns (uint256 dataRoot, uint256 journalHash);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|
|`dstId`|`uint32`|Destination chain identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`dataRoot`|`uint256`|The proof data root|
|`journalHash`|`uint256`|The proof journal hash|


### gasFee

Returns the gas fee for Linea


```solidity
function gasFee() external view returns (uint256 fee);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fee`|`uint256`|Gas fee amount|


## Events
### AllowedCallerUpdated
Emitted when a user updates allowed callers


```solidity
event AllowedCallerUpdated(address indexed sender, address indexed caller, bool status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The caller updating permissions|
|`caller`|`address`|The address whose status is updated|
|`status`|`bool`|Whether the caller is allowed|

### mTokenGateway_Supplied
Emitted when a supply operation is initiated


```solidity
event mTokenGateway_Supplied(
    address indexed from,
    address indexed receiver,
    uint256 accAmountIn,
    uint256 accAmountOut,
    uint256 amount,
    uint32 srcChainId,
    uint32 dstChainId,
    bytes4 lineaMethodSelector
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Sender on source chain|
|`receiver`|`address`|Receiver on destination|
|`accAmountIn`|`uint256`|Accumulated amount in|
|`accAmountOut`|`uint256`|Accumulated amount out|
|`amount`|`uint256`|Supplied amount|
|`srcChainId`|`uint32`|Source chain ID|
|`dstChainId`|`uint32`|Destination chain ID|
|`lineaMethodSelector`|`bytes4`|Linea method selector|

### mTokenGateway_Liquidate
Emitted when a liquidate operation is initiated


```solidity
event mTokenGateway_Liquidate(
    address indexed from,
    address indexed receiver,
    uint256 amount,
    uint32 srcChainId,
    uint32 dstChainId,
    address userToLiquidate,
    address collateral
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Sender on source chain|
|`receiver`|`address`|Receiver of seized collateral|
|`amount`|`uint256`|Liquidation amount|
|`srcChainId`|`uint32`|Source chain ID|
|`dstChainId`|`uint32`|Destination chain ID|
|`userToLiquidate`|`address`|User being liquidated|
|`collateral`|`address`|Collateral market address|

### mTokenGateway_Extracted
Emitted when an extract was finalized


```solidity
event mTokenGateway_Extracted(
    address indexed msgSender,
    address indexed srcSender,
    address indexed receiver,
    uint256 accAmountIn,
    uint256 accAmountOut,
    uint256 amount,
    uint32 srcChainId,
    uint32 dstChainId
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgSender`|`address`|Sender on host chain|
|`srcSender`|`address`|Sender on source chain|
|`receiver`|`address`|Receiver of funds|
|`accAmountIn`|`uint256`|Accumulated amount in|
|`accAmountOut`|`uint256`|Accumulated amount out|
|`amount`|`uint256`|Amount extracted|
|`srcChainId`|`uint32`|Source chain ID|
|`dstChainId`|`uint32`|Destination chain ID|

### mTokenGateway_Skipped
Emitted when a proof was skipped


```solidity
event mTokenGateway_Skipped(
    address indexed msgSender,
    address indexed srcSender,
    address indexed receiver,
    uint256 accAmountIn,
    uint256 accAmountOut,
    uint256 amount,
    uint32 srcChainId,
    uint32 dstChainId
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgSender`|`address`|Sender on host chain|
|`srcSender`|`address`|Sender on source chain|
|`receiver`|`address`|Receiver of funds|
|`accAmountIn`|`uint256`|Accumulated amount in|
|`accAmountOut`|`uint256`|Accumulated amount out|
|`amount`|`uint256`|Amount skipped|
|`srcChainId`|`uint32`|Source chain ID|
|`dstChainId`|`uint32`|Destination chain ID|

### mTokenGateway_GasFeeUpdated
Emitted when the gas fee is updated


```solidity
event mTokenGateway_GasFeeUpdated(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|New gas fee amount|

### mTokenGateway_PausedState
Emitted when pause state changes


```solidity
event mTokenGateway_PausedState(ImTokenOperationTypes.OperationType indexed _type, bool _status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`ImTokenOperationTypes.OperationType`|Operation type paused/unpaused|
|`_status`|`bool`|Pause status|

### ZkVerifierUpdated
Emitted when zk verifier is updated


```solidity
event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldVerifier`|`address`|Previous verifier|
|`newVerifier`|`address`|New verifier|

### mTokenGateway_UserWhitelisted
Emitted when user whitelist status changes


```solidity
event mTokenGateway_UserWhitelisted(address indexed user, bool status);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|
|`status`|`bool`|Whitelist status|

### mTokenGateway_WhitelistEnabled
Emitted when whitelist is enabled


```solidity
event mTokenGateway_WhitelistEnabled();
```

### mTokenGateway_WhitelistDisabled
Emitted when whitelist is disabled


```solidity
event mTokenGateway_WhitelistDisabled();
```

## Errors
### mTokenGateway_ChainNotValid
Thrown when the chain id is not LINEA


```solidity
error mTokenGateway_ChainNotValid();
```

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

### mTokenGateway_NotRebalancer
Thrown when caller is not rebalancer


```solidity
error mTokenGateway_NotRebalancer();
```

### mTokenGateway_LengthNotValid
Thrown when length is not valid


```solidity
error mTokenGateway_LengthNotValid();
```

### mTokenGateway_NotEnoughGasFee
Thrown when not enough gas fee was received


```solidity
error mTokenGateway_NotEnoughGasFee();
```

### mTokenGateway_L1InclusionRequired
Thrown when L1 inclusion is required


```solidity
error mTokenGateway_L1InclusionRequired();
```

### mTokenGateway_UserNotWhitelisted
Thrown when user is not whitelisted


```solidity
error mTokenGateway_UserNotWhitelisted();
```

### mTokenGateway_UserBlacklisted
Thrown when user is blacklisted


```solidity
error mTokenGateway_UserBlacklisted();
```

