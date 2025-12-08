# Deployer
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/utils/Deployer.sol)

**Author:**
Malda Protocol

Minimal helper to precompute and deploy contracts via CREATE3 with two-step admin handover.


## State Variables
### admin
Current admin authorized to deploy and manage ownership


```solidity
address public admin
```


### pendingAdmin
Pending admin address that can accept control


```solidity
address public pendingAdmin
```


## Functions
### onlyAdmin


```solidity
modifier onlyAdmin() ;
```

### constructor

Initializes the deployer


```solidity
constructor(address _admin) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Address that will control deployments|


### receive

Accepts plain ETH transfers


```solidity
receive() external payable;
```

### setPendingAdmin

Propose a new admin that must later accept


```solidity
function setPendingAdmin(address newAdmin) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAdmin`|`address`|Address proposed as the next admin|


### saveEth

Withdraws all ETH to the admin


```solidity
function saveEth() external;
```

### setNewAdmin

Directly sets a new admin (without pending/accept)


```solidity
function setNewAdmin(address _addr) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_addr`|`address`|New admin address|


### create

Deploys a contract using CREATE3


```solidity
function create(bytes32 salt, bytes calldata code) external payable onlyAdmin returns (address deployed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|Deterministic salt used for CREATE3|
|`code`|`bytes`|Creation bytecode to deploy|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`deployed`|`address`|The deployed contract address|


### acceptAdmin

Allows the pending admin to accept control


```solidity
function acceptAdmin() external;
```

### precompute

Precomputes the deployment address for a given salt


```solidity
function precompute(bytes32 salt) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt`|`bytes32`|Deterministic salt used for CREATE3|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address that would be deployed|


## Events
### AdminSet
Emitted when admin is updated


```solidity
event AdminSet(address indexed _admin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|New admin address|

### PendingAdminSet
Emitted when pending admin is set


```solidity
event PendingAdminSet(address indexed _admin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|Pending admin address|

### AdminAccepted
Emitted when pending admin accepts control


```solidity
event AdminAccepted(address indexed _admin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|The admin address that just accepted|

## Errors
### NotAuthorized

```solidity
error NotAuthorized(address admin, address sender);
```

