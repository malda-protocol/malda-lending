# IRoles
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ecf312765013f0471a4707ec1225b346cdb0a535/src\interfaces\IRoles.sol)


## Functions
### GUARDIAN_PAUSE

Returns GUARDIAN_PAUSE role


```solidity
function GUARDIAN_PAUSE() external view returns (bytes32);
```

### GUARDIAN_TRANSFER

Returns GUARDIAN_TRANSFER role


```solidity
function GUARDIAN_TRANSFER() external view returns (bytes32);
```

### GUARDIAN_SEIZE

Returns GUARDIAN_SEIZE role


```solidity
function GUARDIAN_SEIZE() external view returns (bytes32);
```

### GUARDIAN_MINT

Returns GUARDIAN_MINT role


```solidity
function GUARDIAN_MINT() external view returns (bytes32);
```

### GUARDIAN_BORROW

Returns GUARDIAN_BORROW role


```solidity
function GUARDIAN_BORROW() external view returns (bytes32);
```

### GUARDIAN_BORROW_CAP

Returns GUARDIAN_BORROW_CAP role


```solidity
function GUARDIAN_BORROW_CAP() external view returns (bytes32);
```

### GUARDIAN_SUPPLY_CAP

Returns GUARDIAN_SUPPLY_CAP role


```solidity
function GUARDIAN_SUPPLY_CAP() external view returns (bytes32);
```

### GUARDIAN_RESERVE

Returns GUARDIAN_RESERVE role


```solidity
function GUARDIAN_RESERVE() external view returns (bytes32);
```

### isAllowedFor

Returns allowance status for a contract and a role


```solidity
function isAllowedFor(address _contract, bytes32 _role) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|the contract address|
|`_role`|`bytes32`|the bytes32 role|


## Enums
### Pause

```solidity
enum Pause {
    Mint,
    Borrow,
    Transfer,
    Seize
}
```

