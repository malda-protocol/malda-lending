# mTokenConfiguration
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\mToken\mTokenConfiguration.sol)

**Inherits:**
[mTokenStorage](/src\mToken\mTokenStorage.sol\abstract.mTokenStorage.md)


## Functions
### onlyAdmin


```solidity
modifier onlyAdmin();
```

### setOperator

Sets a new Operator for the market

*Admin function to set a new operator*


```solidity
function setOperator(address _operator) external onlyAdmin;
```

### setRolesOperator

Sets a new Operator for the market

*Admin function to set a new operator*


```solidity
function setRolesOperator(address _roles) external onlyAdmin;
```

### setInterestRateModel

accrues interest and updates the interest rate model using _setInterestRateModelFresh

*Admin function to accrue interest and update the interest rate model*


```solidity
function setInterestRateModel(address newInterestRateModel) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterestRateModel`|`address`|the new interest rate model to use|


### setReserveFactor

accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh

*Admin function to accrue interest and set a new reserve factor*


```solidity
function setReserveFactor(uint256 newReserveFactorMantissa) external onlyAdmin;
```

### setPendingAdmin

Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.

*Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.*


```solidity
function setPendingAdmin(address payable newPendingAdmin) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPendingAdmin`|`address payable`|New pending admin.|


### acceptAdmin

Accepts transfer of admin rights. msg.sender must be pendingAdmin

*Admin function for pending admin to accept role and update admin*


```solidity
function acceptAdmin() external;
```

### _setInterestRateModel

updates the interest rate model (*requires fresh interest accrual)

*Admin function to update the interest rate model*


```solidity
function _setInterestRateModel(address newInterestRateModel) internal onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterestRateModel`|`address`|the new interest rate model to use|


### _setOperator


```solidity
function _setOperator(address _operator) internal;
```

