# IPauser
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\IPauser.sol)

**Inherits:**
[ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## Functions
### emergencyPauseMarket

pauses all operations for a market


```solidity
function emergencyPauseMarket(address _market) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|the mToken address|


### emergencyPauseMarketFor

pauses a specific operation for a market


```solidity
function emergencyPauseMarketFor(address _market, OperationType _pauseType) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|the mToken address|
|`_pauseType`|`OperationType`|the operation type|


### emergencyPauseAll

pauses all operations for all registered markets


```solidity
function emergencyPauseAll() external;
```

## Events
### PauseAll

```solidity
event PauseAll();
```

### MarketPaused

```solidity
event MarketPaused(address indexed market);
```

### MarketRemoved

```solidity
event MarketRemoved(address indexed market);
```

### MarketAdded

```solidity
event MarketAdded(address indexed market, PausableType marketType);
```

### MarketPausedFor

```solidity
event MarketPausedFor(address indexed market, OperationType pauseType);
```

## Errors
### Pauser_EntryNotFound

```solidity
error Pauser_EntryNotFound();
```

### Pauser_NotAuthorized

```solidity
error Pauser_NotAuthorized();
```

### Pauser_AddressNotValid

```solidity
error Pauser_AddressNotValid();
```

### Pauser_AlreadyRegistered

```solidity
error Pauser_AlreadyRegistered();
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
    Host,
    Extension
}
```

