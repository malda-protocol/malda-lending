# IPauser
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\IPauser.sol)

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

### Pauser_ContractNotEnabled

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

