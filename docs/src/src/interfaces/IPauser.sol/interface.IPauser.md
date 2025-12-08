# IPauser
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/IPauser.sol)

**Inherits:**
[ImTokenOperationTypes](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/ImToken.sol/interface.ImTokenOperationTypes.md)

**Author:**
Merge Layers Inc.

Interface for pausing market operations


## Functions
### emergencyPauseMarket

Pauses all operations for a market


```solidity
function emergencyPauseMarket(address _market) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|the mToken address|


### emergencyPauseMarketFor

Pauses a specific operation for a market


```solidity
function emergencyPauseMarketFor(address _market, OperationType _pauseType) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|the mToken address|
|`_pauseType`|`OperationType`|the operation type|


### emergencyPauseAll

Pauses all operations for all registered markets


```solidity
function emergencyPauseAll() external;
```

## Events
### PauseAll
Emitted when all markets are paused


```solidity
event PauseAll();
```

### MarketPaused
Emitted when a market is paused


```solidity
event MarketPaused(address indexed market);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|The paused market|

### MarketRemoved
Emitted when a market is removed


```solidity
event MarketRemoved(address indexed market);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|The market removed|

### MarketAdded
Emitted when a market is added


```solidity
event MarketAdded(address indexed market, PausableType marketType);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|The market added|
|`marketType`|`PausableType`|The market type|

### MarketPausedFor
Emitted when a specific operation is paused for a market


```solidity
event MarketPausedFor(address indexed market, OperationType pauseType);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|The market paused|
|`pauseType`|`OperationType`|The operation type paused|

## Errors
### Pauser_EntryNotFound
Error when entry is not found


```solidity
error Pauser_EntryNotFound();
```

### Pauser_NotAuthorized
Error when caller lacks authorization


```solidity
error Pauser_NotAuthorized();
```

### Pauser_AddressNotValid
Error when provided address is invalid


```solidity
error Pauser_AddressNotValid();
```

### Pauser_AlreadyRegistered
Error when market already registered


```solidity
error Pauser_AlreadyRegistered();
```

### Pauser_ContractNotEnabled
Error when contract is not enabled


```solidity
error Pauser_ContractNotEnabled();
```

## Structs
### PausableContract

```solidity
struct PausableContract {
    address market;
    PausableType contractType;
}
```

## Enums
### PausableType

```solidity
enum PausableType {
    NonPausable,
    Host,
    Extension
}
```

