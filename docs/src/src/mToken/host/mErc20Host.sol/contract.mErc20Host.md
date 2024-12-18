# mErc20Host
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\mToken\host\mErc20Host.sol)

**Inherits:**
[mErc20Immutable](/src\mToken\mErc20Immutable.sol\contract.mErc20Immutable.md), [ZkVerifier](/src\verifier\ZkVerifier.sol\abstract.ZkVerifier.md), [ImErc20Host](/src\interfaces\ImErc20Host.sol\interface.ImErc20Host.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## State Variables
### nonces

```solidity
mapping(address => mapping(uint32 => mapping(OperationType => uint32))) public nonces;
```


### logsOperator
Logs manager


```solidity
ImTokenLogs public logsOperator;
```


## Functions
### constructor

Constructs the new money market


```solidity
constructor(
    address underlying_,
    address operator_,
    address interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address payable admin_,
    address zkVerifier_,
    address zkVerifierImageRegistry_,
    address logs_
)
    mErc20Immutable(
        underlying_,
        operator_,
        interestRateModel_,
        initialExchangeRateMantissa_,
        name_,
        symbol_,
        decimals_,
        admin_
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`underlying_`|`address`|The address of the underlying asset|
|`operator_`|`address`|The address of the Operator|
|`interestRateModel_`|`address`|The address of the interest rate model|
|`initialExchangeRateMantissa_`|`uint256`|The initial exchange rate, scaled by 1e18|
|`name_`|`string`|ERC-20 name of this token|
|`symbol_`|`string`|ERC-20 symbol of this token|
|`decimals_`|`uint8`|ERC-20 decimal precision of this token|
|`admin_`|`address payable`|Address of the administrator of this token|
|`zkVerifier_`|`address`|The IRiscZeroVerifier address|
|`zkVerifierImageRegistry_`|`address`|The IZkVerifierImageRegistry address|
|`logs_`|`address`||


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
|`opType`|`OperationType`|The operation type (Mint, Borrow, Repay, Redeem)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|The current nonce for the specified user and operation type|


### setVerifier

Sets the _risc0Verifier address


```solidity
function setVerifier(address _risc0Verifier) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_risc0Verifier`|`address`|the new IRiscZeroVerifier address|


### setVerifierImageRegistry

Sets the ZkVerifierImageRegistry


```solidity
function setVerifierImageRegistry(address _imageRegistry) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageRegistry`|`address`|the new image registry address|


### liquidateExternal

Mints tokens after external verification


```solidity
function liquidateExternal(bytes calldata journalData, bytes calldata seal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|


### mintExternal

Mints tokens after external verification


```solidity
function mintExternal(bytes calldata journalData, bytes calldata seal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|


### borrowExternal

Borrows tokens after external verification


```solidity
function borrowExternal(bytes calldata journalData, bytes calldata seal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for borrowing|
|`seal`|`bytes`|The Zk proof seal|


### borrowOnExtension

Initiates a borrowing operation


```solidity
function borrowOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to borrow|
|`journalData`|`bytes`|The journal data for borrowing|
|`seal`|`bytes`|The Zk proof seal|


### repayExternal

Repays tokens after external verification


```solidity
function repayExternal(bytes calldata journalData, bytes calldata seal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for repayment|
|`seal`|`bytes`|The Zk proof seal|


### withdrawExternal

Withdraws tokens after external verification


```solidity
function withdrawExternal(bytes calldata journalData, bytes calldata seal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for withdrawing|
|`seal`|`bytes`|The Zk proof seal|


### withdrawOnExtension

Initiates a withdraw operation


```solidity
function withdrawOnExtension(uint256 amount, bytes calldata journalData, bytes calldata seal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`||
|`journalData`|`bytes`|The journal data for withdrawing|
|`seal`|`bytes`|The Zk proof seal|


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

