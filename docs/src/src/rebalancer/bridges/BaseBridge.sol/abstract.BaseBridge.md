# BaseBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/rebalancer/bridges/BaseBridge.sol)

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

Modifier to check if the caller is the bridge configurator


```solidity
modifier onlyBridgeConfigurator() ;
```

### onlyRebalancer

Modifier to check if the caller is the rebalancer


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
Error thrown when caller is not authorized


```solidity
error BaseBridge_NotAuthorized();
```

### BaseBridge_AmountMismatch
Error thrown when amount mismatch


```solidity
error BaseBridge_AmountMismatch();
```

### BaseBridge_AmountNotValid
Error thrown when amount is not valid


```solidity
error BaseBridge_AmountNotValid();
```

### BaseBridge_AddressNotValid
Error thrown when address is not valid


```solidity
error BaseBridge_AddressNotValid();
```

