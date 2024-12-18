# IRoles
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\interfaces\IRoles.sol)


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

### PROOF_FORWARDER

Returns PROOF_FORWARDER role


```solidity
function PROOF_FORWARDER() external view returns (bytes32);
```

### LOGS_ADD

Returns LOGS_ADD role


```solidity
function LOGS_ADD() external view returns (bytes32);
```

### PAUSE_MANAGER

Returns PAUSE_MANAGER role


```solidity
function PAUSE_MANAGER() external view returns (bytes32);
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


