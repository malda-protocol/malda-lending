# IUnit
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ecf312765013f0471a4707ec1225b346cdb0a535/src\interfaces\IUnit.sol)


## Functions
### operatorImplementation

Active brains of Unit


```solidity
function operatorImplementation() external view returns (address);
```

### pendingOperatorImplementation

Pending brains of Unit


```solidity
function pendingOperatorImplementation() external view returns (address);
```

### acceptImplementation

Accepts new implementation of Operator. msg.sender must be pendingImplementation

*Admin function for new implementation to accept it's role as implementation*


```solidity
function acceptImplementation() external;
```

