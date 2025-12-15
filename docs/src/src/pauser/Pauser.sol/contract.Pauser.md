# Pauser
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\pauser\Pauser.sol)

**Inherits:**
Ownable, [IPauser](/src\interfaces\IPauser.sol\interface.IPauser.md)


## State Variables
### roles

```solidity
IRoles public immutable roles;
```


### operator

```solidity
IOperator public immutable operator;
```


### pausableContracts

```solidity
PausableContract[] public pausableContracts;
```


### registeredContracts

```solidity
mapping(address _contract => bool _registered) public registeredContracts;
```


### contractTypes

```solidity
mapping(address _contract => PausableType _type) public contractTypes;
```


## Functions
### constructor


```solidity
constructor(address _roles, address _operator, address _owner) Ownable(_owner);
```

### addPausableMarket

add pauable contract


```solidity
function addPausableMarket(address _contract, PausableType _contractType) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|the pausable contract|
|`_contractType`|`PausableType`|the pausable contract type|


### removePausableMarket

removes pauable contract


```solidity
function removePausableMarket(address _contract) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|the pausable contract|


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
function emergencyPauseMarketFor(address _market, ImTokenOperationTypes.OperationType _pauseType) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|the mToken address|
|`_pauseType`|`ImTokenOperationTypes.OperationType`|the operation type|


### emergencyPauseAll

pauses all operations for all registered markets


```solidity
function emergencyPauseAll() external;
```

### _pauseAllMarketOperations


```solidity
function _pauseAllMarketOperations(address _market) private;
```

### _pauseMarketOperation


```solidity
function _pauseMarketOperation(address _market, ImTokenOperationTypes.OperationType _pauseType) private;
```

### _pause


```solidity
function _pause(address _market, ImTokenOperationTypes.OperationType _pauseType) private;
```

### _findIndex


```solidity
function _findIndex(address _address) private view returns (uint256);
```

