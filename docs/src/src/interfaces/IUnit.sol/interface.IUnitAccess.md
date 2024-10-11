# IUnitAccess
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ecf312765013f0471a4707ec1225b346cdb0a535/src\interfaces\IUnit.sol)


## Functions
### admin

Administrator for this contract


```solidity
function admin() external view returns (address);
```

### pendingAdmin

Pending administrator for this contract


```solidity
function pendingAdmin() external view returns (address);
```

### acceptAdmin

Accepts transfer of admin rights. msg.sender must be pendingAdmin

*Admin function for pending admin to accept role and update admin*


```solidity
function acceptAdmin() external;
```

