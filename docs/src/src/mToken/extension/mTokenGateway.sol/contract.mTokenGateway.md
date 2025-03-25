# mTokenGateway
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\mToken\extension\mTokenGateway.sol)

**Inherits:**
OwnableUpgradeable, [ZkVerifier](/src\verifier\ZkVerifier.sol\abstract.ZkVerifier.md), [ImTokenGateway](/src\interfaces\ImTokenGateway.sol\interface.ImTokenGateway.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## State Variables
### rolesOperator
Roles manager


```solidity
IRoles public rolesOperator;
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
function initialize(address payable _owner, address _underlying, address _roles, address zkVerifier_)
    external
    initializer;
```

### notPaused


```solidity
modifier notPaused(OperationType _type);
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


### isCallerAllowed

Returns if a caller is allowed for sender


```solidity
function isCallerAllowed(address sender, address caller) external view returns (bool);
```

### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32) external view returns (uint256, uint256);
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


### setVerifier

Sets the _risc0Verifier address


```solidity
function setVerifier(address _risc0Verifier) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_risc0Verifier`|`address`|the new IRiscZeroVerifier address|


### setImageId

Sets the image id


```solidity
function setImageId(bytes32 _imageId) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the new image id|


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
function withdrawGasFees(address payable receiver) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address payable`|the receiver address|


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
    notPaused(OperationType.AmountIn);
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
    notPaused(OperationType.AmountOutHere);
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
function _verifyProof(bytes calldata journalData, bytes calldata seal) private;
```

### _checkSender


```solidity
function _checkSender(address msgSender, address srcSender) private view;
```

