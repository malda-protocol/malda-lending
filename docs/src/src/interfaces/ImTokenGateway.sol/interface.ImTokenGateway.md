# ImTokenGateway
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\ImTokenGateway.sol)


## Functions
### rolesOperator

Roles


```solidity
function rolesOperator() external view returns (IRoles);
```

### blacklistOperator

Blacklist


```solidity
function blacklistOperator() external view returns (IBlacklister);
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

### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32 dstId) external view returns (uint256, uint256);
```

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


## Events
### AllowedCallerUpdated
Emitted when a user updates allowed callers


```solidity
event AllowedCallerUpdated(address indexed sender, address indexed caller, bool status);
```

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

### mTokenGateway_GasFeeUpdated
Emitted when the gas fee is updated


```solidity
event mTokenGateway_GasFeeUpdated(uint256 amount);
```

### mTokenGateway_PausedState

```solidity
event mTokenGateway_PausedState(ImTokenOperationTypes.OperationType indexed _type, bool _status);
```

### ZkVerifierUpdated

```solidity
event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
```

### mTokenGateway_UserWhitelisted

```solidity
event mTokenGateway_UserWhitelisted(address indexed user, bool status);
```

### mTokenGateway_WhitelistEnabled

```solidity
event mTokenGateway_WhitelistEnabled();
```

### mTokenGateway_WhitelistDisabled

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

