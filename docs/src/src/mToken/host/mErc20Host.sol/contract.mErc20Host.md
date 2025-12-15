# mErc20Host
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\mToken\host\mErc20Host.sol)

**Inherits:**
[mErc20Upgradable](/src\mToken\mErc20Upgradable.sol\abstract.mErc20Upgradable.md), [ImErc20Host](/src\interfaces\ImErc20Host.sol\interface.ImErc20Host.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md)


## State Variables
### migrator

```solidity
address public migrator;
```


### acc

```solidity
mapping(uint32 => Accumulated) internal acc;
```


### allowedCallers

```solidity
mapping(address => mapping(address => bool)) public allowedCallers;
```


### allowedChains

```solidity
mapping(uint32 => bool) public allowedChains;
```


### verifier

```solidity
IZkVerifier public verifier;
```


### gasHelper

```solidity
IGasFeesHelper public gasHelper;
```


## Functions
### onlyMigrator


```solidity
modifier onlyMigrator();
```

### initialize

Initializes the new money market


```solidity
function initialize(
    address underlying_,
    address operator_,
    address interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address payable admin_,
    address zkVerifier_,
    address roles_
) external initializer;
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
|`zkVerifier_`|`address`|The IZkVerifier address|
|`roles_`|`address`||


### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32 dstId) external view returns (uint256, uint256);
```

### updateAllowedChain

Updates an allowed chain status


```solidity
function updateAllowedChain(uint32 _chainId, bool _status) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_chainId`|`uint32`|the chain id|
|`_status`|`bool`|the new status|


### extractForRebalancing

Extract amount to be used for rebalancing operation


```solidity
function extractForRebalancing(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to rebalance|


### setMigrator

Sets the migrator address


```solidity
function setMigrator(address _migrator) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_migrator`|`address`|The new migrator address|


### setGasHelper

Sets the gas fees helper address


```solidity
function setGasHelper(address _helper) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_helper`|`address`|The new helper address|


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
function updateZkVerifier(address _zkVerifier) external onlyAdmin;
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


### liquidateExternal

Mints tokens after external verification


```solidity
function liquidateExternal(
    bytes calldata journalData,
    bytes calldata seal,
    address[] calldata userToLiquidate,
    uint256[] calldata liquidateAmount,
    address[] calldata collateral,
    address receiver
) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting (array of encoded journals)|
|`seal`|`bytes`|The Zk proof seal|
|`userToLiquidate`|`address[]`|Array of positions to liquidate|
|`liquidateAmount`|`uint256[]`|Array of amounts to liquidate|
|`collateral`|`address[]`|Array of collaterals to seize|
|`receiver`|`address`|The collateral receiver|


### mintExternal

Mints tokens after external verification


```solidity
function mintExternal(
    bytes calldata journalData,
    bytes calldata seal,
    uint256[] calldata mintAmount,
    uint256[] calldata minAmountsOut,
    address receiver
) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for minting (array of encoded journals)|
|`seal`|`bytes`|The Zk proof seal|
|`mintAmount`|`uint256[]`|Array of amounts to mint|
|`minAmountsOut`|`uint256[]`|Array of min amounts accepted|
|`receiver`|`address`|The tokens receiver|


### repayExternal

Repays tokens after external verification


```solidity
function repayExternal(
    bytes calldata journalData,
    bytes calldata seal,
    uint256[] calldata repayAmount,
    address receiver
) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The journal data for repayment (array of encoded journals)|
|`seal`|`bytes`|The Zk proof seal|
|`repayAmount`|`uint256[]`|Array of amounts to repay|
|`receiver`|`address`|The position to repay for|


### performExtensionCall

Initiates a withdraw operation


```solidity
function performExtensionCall(uint256 actionType, uint256 amount, uint32 dstChainId) external payable override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`actionType`|`uint256`|The actionType param (1 - withdraw, 2 - borrow)|
|`amount`|`uint256`|The amount to withdraw|
|`dstChainId`|`uint32`|The destination chain to recieve funds|


### mintOrBorrowMigration

Mints mTokens during migration without requiring underlying transfer


```solidity
function mintOrBorrowMigration(bool mint, uint256 amount, address receiver, address borrower, uint256 minAmount)
    external
    onlyMigrator;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mint`|`bool`|Mint or borrow|
|`amount`|`uint256`|The amount of underlying to be accounted for|
|`receiver`|`address`|The address that will receive the mTokens or the underlying in case of borrowing|
|`borrower`|`address`|The address that borrow is executed for|
|`minAmount`|`uint256`|The min amount of underlying to be accounted for|


### _onlyAdminOrRole


```solidity
function _onlyAdminOrRole(bytes32 _role) internal view;
```

### _decodeJournals


```solidity
function _decodeJournals(bytes calldata data) internal pure returns (bytes[] memory);
```

### _checkOutflow


```solidity
function _checkOutflow(uint256 amount) internal;
```

### _checkProofCall


```solidity
function _checkProofCall(uint32 dstChainId, uint32 chainId, address market, address sender) internal view;
```

### _checkSender


```solidity
function _checkSender(address msgSender, address srcSender) internal view;
```

### _getGasFees


```solidity
function _getGasFees(uint32 dstChain) internal view returns (uint256);
```

### _isAllowedFor


```solidity
function _isAllowedFor(address _sender, bytes32 role) internal view returns (bool);
```

### _getChainsManagerRole


```solidity
function _getChainsManagerRole() internal view returns (bytes32);
```

### _getProofForwarderRole


```solidity
function _getProofForwarderRole() internal view returns (bytes32);
```

### _getBatchProofForwarderRole


```solidity
function _getBatchProofForwarderRole() internal view returns (bytes32);
```

### _getSequencerRole


```solidity
function _getSequencerRole() internal view returns (bytes32);
```

### _verifyProof


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) internal view;
```

### _liquidateExternal


```solidity
function _liquidateExternal(
    bytes memory singleJournal,
    address userToLiquidate,
    uint256 liquidateAmount,
    address collateral,
    address receiver
) internal;
```

### _mintExternal


```solidity
function _mintExternal(bytes memory singleJournal, uint256 mintAmount, uint256 minAmountOut, address receiver)
    internal;
```

### _repayExternal


```solidity
function _repayExternal(bytes memory singleJournal, uint256 repayAmount, address receiver) internal;
```

## Structs
### Accumulated

```solidity
struct Accumulated {
    mapping(address => uint256) inPerChain;
    mapping(address => uint256) outPerChain;
}
```

