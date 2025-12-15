# mTokenGateway
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\mToken\extension\mTokenGateway.sol)

**Inherits:**
OwnableUpgradeable, [ImTokenGateway](/src\interfaces\ImTokenGateway.sol\interface.ImTokenGateway.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## State Variables
### rolesOperator
Roles


```solidity
IRoles public rolesOperator;
```


### blacklistOperator
Blacklist


```solidity
IBlacklister public blacklistOperator;
```


### verifier

```solidity
IZkVerifier public verifier;
```


### paused

```solidity
mapping(OperationType => bool) public paused;
```


### underlying
Returns the address of the underlying token


```solidity
address public underlying;
```


### accAmountIn

```solidity
mapping(address => uint256) public accAmountIn;
```


### accAmountOut

```solidity
mapping(address => uint256) public accAmountOut;
```


### allowedCallers

```solidity
mapping(address => mapping(address => bool)) public allowedCallers;
```


### userWhitelisted

```solidity
mapping(address => bool) public userWhitelisted;
```


### whitelistEnabled

```solidity
bool public whitelistEnabled;
```


### LINEA_CHAIN_ID

```solidity
uint32 private constant LINEA_CHAIN_ID = 59144;
```


### gasFee
*gas fee for `supplyOnHost`*


```solidity
uint256 public gasFee;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(
    address payable _owner,
    address _underlying,
    address _roles,
    address _blacklister,
    address zkVerifier_
) external initializer;
```

### notPaused


```solidity
modifier notPaused(OperationType _type);
```

### onlyAllowedUser


```solidity
modifier onlyAllowedUser(address user);
```

### ifNotBlacklisted


```solidity
modifier ifNotBlacklisted(address user);
```

### isPaused

returns pause state for operation


```solidity
function isPaused(OperationType _type) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`OperationType`|the operation type|


### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32) external view returns (uint256, uint256);
```

### setWhitelistedUser

Sets user whitelist status


```solidity
function setWhitelistedUser(address user, bool state) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`state`|`bool`|The new staate|


### enableWhitelist

Enable user whitelist


```solidity
function enableWhitelist() external onlyOwner;
```

### disableWhitelist

Disable user whitelist


```solidity
function disableWhitelist() external onlyOwner;
```

### setPaused

Set pause for a specific operation


```solidity
function setPaused(OperationType _type, bool state) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`OperationType`|The pause operation type|
|`state`|`bool`|The pause operation status|


### extractForRebalancing

Extract amount to be used for rebalancing operation


```solidity
function extractForRebalancing(uint256 amount) external notPaused(OperationType.Rebalancing);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to rebalance|


### setGasFee

Sets the gas fee


```solidity
function setGasFee(uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|the new gas fee|


### withdrawGasFees

Withdraw gas received so far


```solidity
function withdrawGasFees(address payable receiver) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address payable`|the receiver address|


### updateZkVerifier

Updates IZkVerifier address


```solidity
function updateZkVerifier(address _zkVerifier) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_zkVerifier`|`address`|the verifier address|


### updateAllowedCallerStatus

Set caller status for `msg.sender`


```solidity
function updateAllowedCallerStatus(address caller, bool status) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The caller address|
|`status`|`bool`|The status to set for `caller`|


### supplyOnHost

Supply underlying to the contract


```solidity
function supplyOnHost(uint256 amount, address receiver, bytes4 lineaSelector)
    external
    payable
    override
    notPaused(OperationType.AmountIn)
    onlyAllowedUser(msg.sender)
    ifNotBlacklisted(msg.sender)
    ifNotBlacklisted(receiver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The supplied amount|
|`receiver`|`address`|The receiver address|
|`lineaSelector`|`bytes4`|The method selector to be called on Linea by our relayer. If empty, user has to submit it|


### outHere

Extract tokens


```solidity
function outHere(bytes calldata journalData, bytes calldata seal, uint256[] calldata amounts, address receiver)
    external
    notPaused(OperationType.AmountOutHere)
    ifNotBlacklisted(msg.sender)
    ifNotBlacklisted(receiver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The supplied journal|
|`seal`|`bytes`|The seal address|
|`amounts`|`uint256[]`|The amounts to withdraw for each journal|
|`receiver`|`address`|The receiver address|


### _outHere


```solidity
function _outHere(bytes memory journalData, uint256 amount, address receiver) internal;
```

### _verifyProof


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) private view;
```

### _checkSender


```solidity
function _checkSender(address msgSender, address srcSender) private view;
```

### _getSequencerRole


```solidity
function _getSequencerRole() private view returns (bytes32);
```

### _getBatchProofForwarderRole


```solidity
function _getBatchProofForwarderRole() private view returns (bytes32);
```

### _getProofForwarderRole


```solidity
function _getProofForwarderRole() private view returns (bytes32);
```

### _isAllowedFor


```solidity
function _isAllowedFor(address _sender, bytes32 role) private view returns (bool);
```

