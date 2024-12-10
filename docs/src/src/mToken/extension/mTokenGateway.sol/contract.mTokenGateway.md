# mTokenGateway
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\mToken\extension\mTokenGateway.sol)

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


### nonces

```solidity
mapping(address => mapping(uint32 => mapping(OperationType => uint32))) public nonces;
```


### _underlyingDecimals

```solidity
uint8 private _underlyingDecimals;
```


### LINEA_CHAIN_ID

```solidity
uint32 private constant LINEA_CHAIN_ID = 59144;
```


## Functions
### constructor


```solidity
constructor(
    address payable _owner,
    address _underlying,
    address _roles,
    address zkVerifier_,
    address zkVerifierImageRegistry_,
    address _logs
)
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

### getNonce

Retrieves the current nonce for a user and operation type


```solidity
function getNonce(address user, uint32 chainId, OperationType opType) external view returns (uint32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`chainId`|`uint32`|The chainId to get the data for|
|`opType`|`OperationType`|The operation type (Mint, Borrow, Repay, Withdraw, Release)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The current nonce for the specified user and operation type|


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


### setVerifierImageRegistry

Sets the ZkVerifierImageRegistry


```solidity
function setVerifierImageRegistry(address _imageRegistry) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageRegistry`|`address`|the new image registry address|


### liquidateOnHost

Initiates a liquidation request to be fulfilled on host

*`collateral` can be address(0)*


```solidity
function liquidateOnHost(uint256 amount, address user, address collateral)
    external
    override
    notPaused(OperationType.LiquidateOnOtherChain);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to liquidate|
|`user`|`address`|The position to liquidate|
|`collateral`|`address`|The collateral to receive|


### mintOnHost

Mints new tokens by transferring the underlying token from the user


```solidity
function mintOnHost(uint256 amount) external override notPaused(OperationType.MintOnOtherChain);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to mint|


### borrowOnHost

Initiates a borrowing operation


```solidity
function borrowOnHost(uint256 amount) external override notPaused(OperationType.BorrowOnOtherChain);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to borrow|


### borrowExternal

Finalizes a borrow action initiated from host chain


```solidity
function borrowExternal(bytes calldata journalData, bytes calldata seal)
    external
    override
    notPaused(OperationType.Borrow);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data containing the release information|
|`seal`|`bytes`|The zk-proof data required to verify the release|


### repayOnHost

Repays a borrowed amount by transferring the underlying token from the user


```solidity
function repayOnHost(uint256 amount) external notPaused(OperationType.RepayOnOtherChain);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to repay|


### withdrawOnHost

Withdraws tokens and burns the corresponding minted tokens


```solidity
function withdrawOnHost(uint256 amount) external notPaused(OperationType.RedeemOnOtherChain);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to withdraw|


### withdrawExternal

Releases tokens to a user based on a validated zk-proof and journal data


```solidity
function withdrawExternal(bytes calldata journalData, bytes calldata seal) external notPaused(OperationType.Redeem);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data containing the release information|
|`seal`|`bytes`|The zk-proof data required to verify the release|


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
function _verifyProof(OperationType imageType, bytes calldata journalData, bytes calldata seal) private;
```

### _getNonce


```solidity
function _getNonce(address from, uint32 chainId, OperationType operation) private view returns (uint32);
```

### _increaseNonce


```solidity
function _increaseNonce(address from, uint32 chainId, OperationType operation) private;
```

### _checkSender


```solidity
function _checkSender(address sender, address user) private view;
```

