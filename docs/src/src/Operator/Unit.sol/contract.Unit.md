# Unit
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\Operator\Unit.sol)

**Inherits:**
[IUnit](/src\interfaces\IUnit.sol\interface.IUnit.md), [IUnitAccess](/src\interfaces\IUnit.sol\interface.IUnitAccess.md)


## State Variables
### admin
Administrator for this contract


```solidity
address public admin;
```


### pendingAdmin
Pending administrator for this contract


```solidity
address public pendingAdmin;
```


### operatorImplementation
Active brains of Unit


```solidity
address public operatorImplementation;
```


### pendingOperatorImplementation
Pending brains of Unit


```solidity
address public pendingOperatorImplementation;
```


## Functions
### onlyAdmin


```solidity
modifier onlyAdmin();
```

### constructor


```solidity
constructor(address _admin);
```

### setPendingImplementation

Sets a pending implementation


```solidity
function setPendingImplementation(address newPendingImplementation) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPendingImplementation`|`address`|The new implementation address|


### acceptImplementation

Accepts new implementation of Operator. msg.sender must be pendingImplementation

*Admin function for new implementation to accept it's role as implementation*


```solidity
function acceptImplementation() external override;
```

### setPendingAdmin

Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.

*Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.*


```solidity
function setPendingAdmin(address newPendingAdmin) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPendingAdmin`|`address`|New pending admin.|


### acceptAdmin

Accepts transfer of admin rights. msg.sender must be pendingAdmin

*Admin function for pending admin to accept role and update admin*


```solidity
function acceptAdmin() external override;
```

### fallback

*Delegates execution to an implementation contract.
It returns to the external caller whatever the implementation returns
or forwards reverts.*


```solidity
fallback() external payable;
```

### receive


```solidity
receive() external payable;
```

## Events
### NewPendingImplementation
Emitted when pendingOperatorImplementation is changed


```solidity
event NewPendingImplementation(address oldPendingImplementation, address newPendingImplementation);
```

### NewImplementation
Emitted when pendingOperatorImplementation is accepted, which means Operator implementation is updated


```solidity
event NewImplementation(address oldImplementation, address newImplementation);
```

### NewPendingAdmin
Emitted when pendingAdmin is changed


```solidity
event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
```

### NewAdmin
Emitted when pendingAdmin is accepted, which means admin is updated


```solidity
event NewAdmin(address oldAdmin, address newAdmin);
```

## Errors
### Unit_OnlyAdmin

```solidity
error Unit_OnlyAdmin();
```

