# IUnit
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\IUnit.sol)


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

