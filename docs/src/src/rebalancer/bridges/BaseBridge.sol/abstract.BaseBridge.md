# BaseBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\rebalancer\bridges\BaseBridge.sol)


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

