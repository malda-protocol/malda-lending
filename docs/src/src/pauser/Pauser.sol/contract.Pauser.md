# Pauser
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/pauser/Pauser.sol)

**Inherits:**
Ownable, [IPauser](/src/interfaces/IPauser.sol/interface.IPauser.md)

**Title:**
Pauser

**Author:**
Merge Layers Inc.

Manages pausing operations across deployed markets


## State Variables
### ROLES
Roles contract reference


```solidity
IRoles public immutable ROLES
```


### OPERATOR
Operator contract reference


```solidity
IOperator public immutable OPERATOR
```


### pausableContracts
List of contracts that can be paused


```solidity
PausableContract[] public pausableContracts
```


### registeredContracts
Tracks whether a contract is registered as pausable


```solidity
mapping(address _contract => bool _registered) public registeredContracts
```


### contractTypes
Contract type for each registered market


```solidity
mapping(address _contract => PausableType _type) public contractTypes
```


## Functions
### constructor

Sets initial configuration for roles, operator, and owner


```solidity
constructor(address _roles, address _operator, address owner_) Ownable(owner_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|Address of the roles contract|
|`_operator`|`address`|Address of the operator contract|
|`owner_`|`address`|Owner address of the pauser contract|


### addPausableMarket

Add pausable contract


```solidity
function addPausableMarket(address _contract, PausableType _contractType) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|the pausable contract|
|`_contractType`|`PausableType`|the pausable contract type|


### removePausableMarket

Removes pausable contract


```solidity
function removePausableMarket(address _contract) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|the pausable contract|


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


```solidity
function emergencyPauseMarketFor(address _market, ImTokenOperationTypes.OperationType _pauseType) external;
```

### emergencyPauseAll

Pauses all operations for all registered markets


```solidity
function emergencyPauseAll() external;
```

### _pauseAllMarketOperations

Pauses all market operations for a given market


```solidity
function _pauseAllMarketOperations(address _market) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|The market to pause|


### _pauseMarketOperation

Pauses a specific market operation type


```solidity
function _pauseMarketOperation(address _market, ImTokenOperationTypes.OperationType _pauseType) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|The market to pause|
|`_pauseType`|`ImTokenOperationTypes.OperationType`|The operation type to pause|


### _pause

Performs pause logic depending on contract type


```solidity
function _pause(address _market, ImTokenOperationTypes.OperationType _pauseType) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|The market address to pause|
|`_pauseType`|`ImTokenOperationTypes.OperationType`|The operation type to pause|


### _findIndex

Finds the index of a market within the pausableContracts array


```solidity
function _findIndex(address _address) private view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The market address to search for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|index The index of the market|


