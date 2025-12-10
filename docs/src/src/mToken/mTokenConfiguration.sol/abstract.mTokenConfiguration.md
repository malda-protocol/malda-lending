# mTokenConfiguration
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/mToken/mTokenConfiguration.sol)

**Inherits:**
[mTokenStorage](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/mToken/mTokenStorage.sol/abstract.mTokenStorage.md)

**Author:**
Merge Layers Inc.

Configuration helpers for mToken markets


## Functions
### onlyAdmin


```solidity
modifier onlyAdmin() ;
```

### setOperator

Sets a new Operator for the market


```solidity
function setOperator(address _operator) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The new operator address|


### setRolesOperator

Sets a new Roles operator for the market


```solidity
function setRolesOperator(address _roles) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|The roles contract address|


### setInterestRateModel

Accrues interest and updates the interest rate model using _setInterestRateModelFresh


```solidity
function setInterestRateModel(address newInterestRateModel) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterestRateModel`|`address`|The new interest rate model to use|


### setBorrowRateMaxMantissa

Sets the maximum borrow rate mantissa


```solidity
function setBorrowRateMaxMantissa(uint256 maxMantissa) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxMantissa`|`uint256`|The new max mantissa|


### setReserveFactor

Accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh

Admin function to accrue interest and set a new reserve factor


```solidity
function setReserveFactor(uint256 newReserveFactorMantissa) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newReserveFactorMantissa`|`uint256`|The new reserve factor mantissa|


### setPendingAdmin

Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.

Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.


```solidity
function setPendingAdmin(address payable newPendingAdmin) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newPendingAdmin`|`address payable`|New pending admin.|


### acceptAdmin

Accepts transfer of admin rights. msg.sender must be pendingAdmin

Admin function for pending admin to accept role and update admin


```solidity
function acceptAdmin() external;
```

### _setInterestRateModel

Updates the interest rate model (*requires fresh interest accrual)

Admin function to update the interest rate model


```solidity
function _setInterestRateModel(address newInterestRateModel) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newInterestRateModel`|`address`|The new interest rate model to use|


### _setOperator

Sets the Operator contract address


```solidity
function _setOperator(address _operator) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|The operator address|


