# IRoles
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/interfaces/IRoles.sol)

**Author:**
Merge Layers Inc.

Interface for protocol role management


## Functions
### REBALANCER

Returns REBALANCER role


```solidity
function REBALANCER() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|REBALANCER role identifier|


### REBALANCER_EOA

Returns REBALANCER_EOA role


```solidity
function REBALANCER_EOA() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|REBALANCER_EOA role identifier|


### GUARDIAN_PAUSE

Returns GUARDIAN_PAUSE role


```solidity
function GUARDIAN_PAUSE() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|GUARDIAN_PAUSE role identifier|


### GUARDIAN_BRIDGE

Returns GUARDIAN_BRIDGE role


```solidity
function GUARDIAN_BRIDGE() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|GUARDIAN_BRIDGE role identifier|


### GUARDIAN_BORROW_CAP

Returns GUARDIAN_BORROW_CAP role


```solidity
function GUARDIAN_BORROW_CAP() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|GUARDIAN_BORROW_CAP role identifier|


### GUARDIAN_SUPPLY_CAP

Returns GUARDIAN_SUPPLY_CAP role


```solidity
function GUARDIAN_SUPPLY_CAP() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|GUARDIAN_SUPPLY_CAP role identifier|


### GUARDIAN_RESERVE

Returns GUARDIAN_RESERVE role


```solidity
function GUARDIAN_RESERVE() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|GUARDIAN_RESERVE role identifier|


### PROOF_FORWARDER

Returns PROOF_FORWARDER role


```solidity
function PROOF_FORWARDER() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|PROOF_FORWARDER role identifier|


### PROOF_BATCH_FORWARDER

Returns PROOF_BATCH_FORWARDER role


```solidity
function PROOF_BATCH_FORWARDER() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|PROOF_BATCH_FORWARDER role identifier|


### SEQUENCER

Returns SEQUENCER role


```solidity
function SEQUENCER() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|SEQUENCER role identifier|


### PAUSE_MANAGER

Returns PAUSE_MANAGER role


```solidity
function PAUSE_MANAGER() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|PAUSE_MANAGER role identifier|


### CHAINS_MANAGER

Returns CHAINS_MANAGER role


```solidity
function CHAINS_MANAGER() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|CHAINS_MANAGER role identifier|


### GUARDIAN_ORACLE

Returns GUARDIAN_ORACLE role


```solidity
function GUARDIAN_ORACLE() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|GUARDIAN_ORACLE role identifier|


### GUARDIAN_BLACKLIST

Returns GUARDIAN_BLACKLIST role


```solidity
function GUARDIAN_BLACKLIST() external view returns (bytes32 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`bytes32`|GUARDIAN_BLACKLIST role identifier|


### isAllowedFor

Returns allowance status for a contract and a role


```solidity
function isAllowedFor(address _contract, bytes32 _role) external view returns (bool isAllowed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|The contract address|
|`_role`|`bytes32`|The bytes32 role|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isAllowed`|`bool`|True if allowed|


## Errors
### Roles_InputNotValid
Error thrown when input is not valid


```solidity
error Roles_InputNotValid();
```

