# HypernativeFirewallProtected
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/libraries/HypernativeFirewallProtected.sol)


## State Variables
### HYPERNATIVE_ORACLE_STORAGE_SLOT

```solidity
bytes32 private constant HYPERNATIVE_ORACLE_STORAGE_SLOT =
    bytes32(uint256(keccak256("eip1967.hypernative.firewall")) - 1)
```


### HYPERNATIVE_ADMIN_STORAGE_SLOT

```solidity
bytes32 private constant HYPERNATIVE_ADMIN_STORAGE_SLOT =
    bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1)
```


### HYPERNATIVE_MODE_STORAGE_SLOT

```solidity
bytes32 private constant HYPERNATIVE_MODE_STORAGE_SLOT =
    bytes32(uint256(keccak256("eip1967.hypernative.is_strict_mode")) - 1)
```


## Functions
### onlyFirewallApproved


```solidity
modifier onlyFirewallApproved() ;
```

### onlyFirewallApprovedAllowEOA


```solidity
modifier onlyFirewallApprovedAllowEOA() ;
```

### onlyNotBlacklistedEOA


```solidity
modifier onlyNotBlacklistedEOA() ;
```

### onlyFirewallAdmin


```solidity
modifier onlyFirewallAdmin() ;
```

### _initHypernativeFirewall


```solidity
function _initHypernativeFirewall(address _firewall, address _admin) internal;
```

### firewallRegister


```solidity
function firewallRegister(address _account) public virtual;
```

### setFirewall

Admin only function, sets new firewall admin. set to address(0) to revoke firewall


```solidity
function setFirewall(address _firewall) public onlyFirewallAdmin;
```

### setIsStrictMode


```solidity
function setIsStrictMode(bool _mode) public onlyFirewallAdmin;
```

### changeFirewallAdmin


```solidity
function changeFirewallAdmin(address _newAdmin) public onlyFirewallAdmin;
```

### _changeFirewallAdmin


```solidity
function _changeFirewallAdmin(address _newAdmin) internal;
```

### _setAddressBySlot


```solidity
function _setAddressBySlot(bytes32 slot, address newAddress) internal;
```

### _setValueBySlot


```solidity
function _setValueBySlot(bytes32 _slot, uint256 _value) internal;
```

### hypernativeFirewallAdmin


```solidity
function hypernativeFirewallAdmin() public view returns (address);
```

### _hypernativeFirewallIsStrictMode


```solidity
function _hypernativeFirewallIsStrictMode() private view returns (bool);
```

### _hypernativeFirewall


```solidity
function _hypernativeFirewall() private view returns (address);
```

### _getAddressBySlot


```solidity
function _getAddressBySlot(bytes32 slot) internal view returns (address addr);
```

### _getValueBySlot


```solidity
function _getValueBySlot(bytes32 _slot) internal view returns (uint256 value);
```

## Events
### FirewallAdminChanged

```solidity
event FirewallAdminChanged(address indexed previousAdmin, address indexed newAdmin);
```

### FirewallAddressChanged

```solidity
event FirewallAddressChanged(address indexed previousFirewall, address indexed newFirewall);
```

