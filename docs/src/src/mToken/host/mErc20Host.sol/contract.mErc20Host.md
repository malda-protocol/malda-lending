# mErc20Host
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\mToken\host\mErc20Host.sol)

**Inherits:**
[mErc20Immutable](/src\mToken\mErc20Immutable.sol\contract.mErc20Immutable.md), [ZkVerifier](/src\verifier\ZkVerifier.sol\abstract.ZkVerifier.md), [ImErc20Host](/src\interfaces\ImErc20Host.sol\interface.ImErc20Host.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## State Variables
### nonce

```solidity
uint32 public nonce;
```


### accAmountInPerChain

```solidity
mapping(uint32 => mapping(address => uint256)) public accAmountInPerChain;
```


### accAmountOutPerChain

```solidity
mapping(uint32 => mapping(address => uint256)) public accAmountOutPerChain;
```


### DEFAULT_NONCE

```solidity
int32 private constant DEFAULT_NONCE = -1;
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
|`logs_`|`address`||


### setVerifier

Sets the _risc0Verifier address


```solidity
function setVerifier(address _risc0Verifier) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_risc0Verifier`|`address`|the new IRiscZeroVerifier address|


### setImageId

Sets the image id


```solidity
function setImageId(bytes32 _imageId) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_imageId`|`bytes32`|the new image id|


### liquidateExternal

Mints tokens after external verification


```solidity
function liquidateExternal(bytes calldata journalData, bytes calldata seal, uint256 liquidateAmount, address collateral)
    external
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|
|`liquidateAmount`|`uint256`|The amount to liquidate|
|`collateral`|`address`|The collateral to seize|


### mintExternal

Mints tokens after external verification


```solidity
function mintExternal(bytes calldata journalData, bytes calldata seal, uint256 mintAmount) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting|
|`seal`|`bytes`|The Zk proof seal|
|`mintAmount`|`uint256`|The amount to mint|


### borrowExternal

Borrows tokens after external verification


```solidity
function borrowExternal(bytes calldata journalData, bytes calldata seal, uint256 borrowAmount) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for borrowing|
|`seal`|`bytes`|The Zk proof seal|
|`borrowAmount`|`uint256`|The amount to borrow|


### repayExternal

Repays tokens after external verification


```solidity
function repayExternal(bytes calldata journalData, bytes calldata seal, uint256 repayAmount) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for repayment|
|`seal`|`bytes`|The Zk proof seal|
|`repayAmount`|`uint256`|The amount to repay|


### withdrawExternal

Withdraws tokens after external verification


```solidity
function withdrawExternal(bytes calldata journalData, bytes calldata seal, uint256 amount) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for withdrawing|
|`seal`|`bytes`|The Zk proof seal|
|`amount`|`uint256`|The amount to withdraw|


### withdrawOnExtension

Initiates a withdraw operation


```solidity
function withdrawOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to withdraw|
|`dstChainId`|`uint32`|The destination chain to recieve funds|
|`allowedCallers`|`address[]`|The allowed callers for destination chain finalization|


### borrowOnExtension


```solidity
function borrowOnExtension(uint256 amount, uint32 dstChainId, address[] calldata allowedCallers) external override;
```

### _verifyProof


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) private;
```

### _decodeJournal


```solidity
function _decodeJournal(bytes calldata journalData)
    private
    pure
    returns (
        address _sender,
        address _user,
        uint256 _accAmount,
        uint32 _chainId,
        uint32 _srcNonce,
        address[] memory _allowedCallers
    );
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

