# BaseBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/rebalancer/bridges/BaseBridge.sol)

**Author:**
Malda Protocol

Abstract base for cross-chain bridge implementations with role-based access control


## State Variables
### roles
Roles contract for access control


```solidity
IRoles public roles
```


## Functions
### onlyBridgeConfigurator


```solidity
modifier onlyBridgeConfigurator() ;
```

### onlyRebalancer


```solidity
modifier onlyRebalancer() ;
```

### constructor

Initializes the base bridge


```solidity
constructor(address _roles) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|Roles contract address|


## Errors
### BaseBridge_NotAuthorized

```solidity
error BaseBridge_NotAuthorized();
```

### BaseBridge_AmountMismatch

```solidity
error BaseBridge_AmountMismatch();
```

### BaseBridge_AmountNotValid

```solidity
error BaseBridge_AmountNotValid();
```

### BaseBridge_AddressNotValid

```solidity
error BaseBridge_AddressNotValid();
```

