# IUnitAccess
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\IUnit.sol)


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

