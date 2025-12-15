# IRoles
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\IRoles.sol)


## Functions
### REBALANCER

Returns REBALANCER role


```solidity
function REBALANCER() external view returns (bytes32);
```

### REBALANCER_EOA

Returns REBALANCER_EOA role


```solidity
function REBALANCER_EOA() external view returns (bytes32);
```

### GUARDIAN_PAUSE

Returns GUARDIAN_PAUSE role


```solidity
function GUARDIAN_PAUSE() external view returns (bytes32);
```

### GUARDIAN_BRIDGE

Returns GUARDIAN_BRIDGE role


```solidity
function GUARDIAN_BRIDGE() external view returns (bytes32);
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

### PROOF_BATCH_FORWARDER

Returns PROOF_BATCH_FORWARDER role


```solidity
function PROOF_BATCH_FORWARDER() external view returns (bytes32);
```

### SEQUENCER

Returns SEQUENCER role


```solidity
function SEQUENCER() external view returns (bytes32);
```

### PAUSE_MANAGER

Returns PAUSE_MANAGER role


```solidity
function PAUSE_MANAGER() external view returns (bytes32);
```

### CHAINS_MANAGER

Returns CHAINS_MANAGER role


```solidity
function CHAINS_MANAGER() external view returns (bytes32);
```

### GUARDIAN_ORACLE

Returns GUARDIAN_ORACLE role


```solidity
function GUARDIAN_ORACLE() external view returns (bytes32);
```

### GUARDIAN_BLACKLIST

Returns GUARDIAN_BLACKLIST role


```solidity
function GUARDIAN_BLACKLIST() external view returns (bytes32);
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


## Errors
### Roles_InputNotValid

```solidity
error Roles_InputNotValid();
```

