# mTokenGateway
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\mToken\extension\mTokenGateway.sol)

**Inherits:**
Ownable, ERC20, [ZkVerifier](/src\verifier\ZkVerifier.sol\abstract.ZkVerifier.md), [ImTokenGateway](/src\interfaces\ImTokenGateway.sol\interface.ImTokenGateway.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## State Variables
### rolesOperator
Roles manager


```solidity
IRoles public rolesOperator;
```


### logsOperator
Logs manager


```solidity
ImTokenLogs public logsOperator;
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


### _underlyingDecimals

```solidity
uint8 private _underlyingDecimals;
```


### nonce

```solidity
uint32 public nonce;
```


### accAmountIn

```solidity
mapping(address => uint256) public accAmountIn;
```


### accAmountOut

```solidity
mapping(address => uint256) public accAmountOut;
```


### DEFAULT_NONCE

```solidity
int32 private constant DEFAULT_NONCE = -1;
```


### LINEA_CHAIN_ID

```solidity
uint32 private constant LINEA_CHAIN_ID = 59144;
```


## Functions
### constructor


```solidity
constructor(address payable _owner, address _underlying, address _roles, address zkVerifier_, address _logs)
    Ownable(_owner)
    ERC20(
        string.concat("pending_", IERC20Metadata(_underlying).name()),
        string.concat("p_", IERC20Metadata(_underlying).symbol())
    );
```

### notPaused


```solidity
modifier notPaused(OperationType _type);
```

### decimals

return the decimals value


```solidity
function decimals() public view override returns (uint8);
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


### supplyOnHost

Supply underlying to the contractr


```solidity
function supplyOnHost(uint256 amount, address user, address[] calldata allowedCallers)
    external
    override
    notPaused(OperationType.AmountIn);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The supplied amount|
|`user`|`address`|The user to supply for|
|`allowedCallers`|`address[]`|The allowed callers for host chain interactions|


### outOnHost

Supply underlying to the contractr


```solidity
function outOnHost(uint256 amount, address user, address[] calldata allowedCallers)
    external
    override
    notPaused(OperationType.AmountOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The supplied amount|
|`user`|`address`|The user to supply for|
|`allowedCallers`|`address[]`|The allowed callers for host chain interactions|


### outHere

Extract tokens


```solidity
function outHere(bytes calldata journalData, bytes calldata seal, uint256 amount)
    external
    override
    notPaused(OperationType.AmountOutHere);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The supplied journal|
|`seal`|`bytes`|The seal address|
|`amount`|`uint256`|The amount to use|


### transfer

*Non-transferable*


```solidity
function transfer(address, uint256) public pure override returns (bool);
```

### transferFrom

*Non-transferable*


```solidity
function transferFrom(address, address, uint256) public pure override returns (bool);
```

### _verifyProof


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) private;
```

### _extractCallers


```solidity
function _extractCallers(bytes calldata journalData, uint256 allowedCallersOffset)
    private
    pure
    returns (address[] memory allowedCallers);
```

### _checkSender


```solidity
function _checkSender(address sender, address user, address[] memory allowedCallers) private view;
```

