# Roles
[Git Source](https://github.com/malda-protocol/malda-lending/blob/00d040411754d9ec62fde1c26b93be292ca3e328/src\Roles.sol)

**Inherits:**
Ownable, [IRoles](/src\interfaces\IRoles.sol\interface.IRoles.md)


## State Variables
### _roles

```solidity
mapping(address => mapping(bytes32 => bool)) private _roles;
```


### GUARDIAN_PAUSE

```solidity
bytes32 public constant GUARDIAN_PAUSE = keccak256("GUARDIAN_PAUSE");
```


### GUARDIAN_TRANSFER

```solidity
bytes32 public constant GUARDIAN_TRANSFER = keccak256("GUARDIAN_TRANSFER");
```


### GUARDIAN_SEIZE

```solidity
bytes32 public constant GUARDIAN_SEIZE = keccak256("GUARDIAN_SEIZE");
```


### GUARDIAN_MINT

```solidity
bytes32 public constant GUARDIAN_MINT = keccak256("GUARDIAN_MINT");
```


### GUARDIAN_BORROW

```solidity
bytes32 public constant GUARDIAN_BORROW = keccak256("GUARDIAN_BORROW");
```


### GUARDIAN_BORROW_CAP

```solidity
bytes32 public constant GUARDIAN_BORROW_CAP = keccak256("GUARDIAN_BORROW_CAP");
```


### GUARDIAN_SUPPLY_CAP

```solidity
bytes32 public constant GUARDIAN_SUPPLY_CAP = keccak256("GUARDIAN_SUPPLY_CAP");
```


## Functions
### constructor


```solidity
constructor(address _owner) Ownable(_owner);
```

### allowedFor


```solidity
function allowedFor(address _contract, bytes32 _role) external view override returns (bool);
```

### allowFor

Abiltity to allow a contract for a role or not


```solidity
function allowFor(address _contract, bytes32 _role, bool _allowed) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|the contract's address.|
|`_role`|`bytes32`|the bytes32 role.|
|`_allowed`|`bool`|the new status.|


## Events
### Allowed
emitted when role is set


```solidity
event Allowed(address indexed _contract, bytes32 indexed _role, bool _allowed);
```

## Errors
### Roles_NotAuthorized

```solidity
error Roles_NotAuthorized();
```

