# BaseBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/acd5ab2b6c54b66703c366d922b6691b77a8c9fd/src\rebalancer\bridges\BaseBridge.sol)


## State Variables
### roles

```solidity
IRoles public roles;
```


## Functions
### constructor


```solidity
constructor(address _roles);
```

### onlyBridgeConfigurator


```solidity
modifier onlyBridgeConfigurator();
```

### onlyRebalancer


```solidity
modifier onlyRebalancer();
```

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

