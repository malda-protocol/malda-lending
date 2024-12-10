# IUnitAccess
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\interfaces\IUnit.sol)


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

