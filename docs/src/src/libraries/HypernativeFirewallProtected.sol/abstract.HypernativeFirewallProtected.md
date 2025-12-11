# HypernativeFirewallProtected
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/libraries/HypernativeFirewallProtected.sol)

**Title:**
HypernativeFirewallProtected

**Author:**
Merge Layers Inc.

Abstract contract that provides firewall protection for the contract


## State Variables
### HYPERNATIVE_ORACLE_STORAGE_SLOT
Storage slot for the firewall address


```solidity
bytes32 private constant HYPERNATIVE_ORACLE_STORAGE_SLOT =
    bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1)
```


### HYPERNATIVE_ADMIN_STORAGE_SLOT
Storage slot for the firewall admin address


```solidity
bytes32 private constant HYPERNATIVE_ADMIN_STORAGE_SLOT =
    bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1)
```


### HYPERNATIVE_MODE_STORAGE_SLOT
Storage slot for the firewall strict mode


```solidity
bytes32 private constant HYPERNATIVE_MODE_STORAGE_SLOT =
    bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1)
```


## Functions
### onlyFirewallApproved

Modifier to restrict access to only approved firewall addresses


```solidity
modifier onlyFirewallApproved() ;
```

### onlyFirewallApprovedAllowEOA

Modifier to restrict access to only approved firewall addresses and EOAs


```solidity
modifier onlyFirewallApprovedAllowEOA() ;
```

### onlyNotBlacklistedEOA

Modifier to restrict access to only not blacklisted EOAs


```solidity
modifier onlyNotBlacklistedEOA() ;
```

### onlyFirewallAdmin

Modifier to restrict access to only the firewall admin


```solidity
modifier onlyFirewallAdmin() ;
```

### firewallRegister

Function to register an account with the firewall


```solidity
function firewallRegister(address _account) public virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The account to register|


### setFirewall

Function to set the firewall

Admin only function, sets new firewall admin. set to address(0) to revoke firewall


```solidity
function setFirewall(address _firewall) public onlyFirewallAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_firewall`|`address`|The new firewall address|


### setIsStrictMode

Function to set the strict mode


```solidity
function setIsStrictMode(bool _mode) public onlyFirewallAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mode`|`bool`|The strict mode|


### changeFirewallAdmin

Function to change the firewall admin


```solidity
function changeFirewallAdmin(address _newAdmin) public onlyFirewallAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newAdmin`|`address`|The new firewall admin address|


### hypernativeFirewallAdmin

Function to get the firewall admin


```solidity
function hypernativeFirewallAdmin() public view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The firewall admin address|


### _initHypernativeFirewall

Internal function to initialize the firewall


```solidity
function _initHypernativeFirewall(address _firewall, address _admin) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_firewall`|`address`|The firewall address|
|`_admin`|`address`|The firewall admin address|


### _changeFirewallAdmin

Internal function to change the firewall admin


```solidity
function _changeFirewallAdmin(address _newAdmin) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_newAdmin`|`address`|The new firewall admin address|


### _setAddressBySlot

Internal function to set the address in the slot


```solidity
function _setAddressBySlot(bytes32 slot, address newAddress) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The slot to set the address in|
|`newAddress`|`address`|The address to set in the slot|


### _setValueBySlot

Internal function to set the value in the slot


```solidity
function _setValueBySlot(bytes32 _slot, uint256 _value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_slot`|`bytes32`|The slot to set the value in|
|`_value`|`uint256`|The value to set in the slot|


### _getAddressBySlot

Internal function to get the address from the slot


```solidity
function _getAddressBySlot(bytes32 slot) internal view returns (address addr);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|The slot to get the address from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address from the slot|


### _getValueBySlot

Internal function to get the value from the slot


```solidity
function _getValueBySlot(bytes32 _slot) internal view returns (uint256 value);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_slot`|`bytes32`|The slot to get the value from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`value`|`uint256`|The value from the slot|


### _hypernativeFirewallIsStrictMode

Internal function to get the strict mode


```solidity
function _hypernativeFirewallIsStrictMode() private view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|The strict mode|


### _hypernativeFirewall

Internal function to get the firewall address


```solidity
function _hypernativeFirewall() private view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The firewall address|


## Events
### FirewallAdminChanged
Emitted when the firewall admin is changed


```solidity
event FirewallAdminChanged(address indexed previousAdmin, address indexed newAdmin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`previousAdmin`|`address`|The previous firewall admin address|
|`newAdmin`|`address`|The new firewall admin address|

### FirewallAddressChanged
Emitted when the firewall address is changed


```solidity
event FirewallAddressChanged(address indexed previousFirewall, address indexed newFirewall);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`previousFirewall`|`address`|The previous firewall address|
|`newFirewall`|`address`|The new firewall address|

## Errors
### HypernativeFirewallProtected_CallerNotEOA
Thrown when the caller is not an EOA


```solidity
error HypernativeFirewallProtected_CallerNotEOA();
```

### HypernativeFirewallProtected_CallerNotFirewallAdmin
Thrown when the caller is not the firewall admin


```solidity
error HypernativeFirewallProtected_CallerNotFirewallAdmin();
```

### HypernativeFirewallProtected_AddressNotValid
Thrown when the address is not valid


```solidity
error HypernativeFirewallProtected_AddressNotValid();
```

