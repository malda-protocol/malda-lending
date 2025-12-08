# mErc20Host
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/mToken/host/mErc20Host.sol)

**Inherits:**
[mErc20Upgradable](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/mToken/mErc20Upgradable.sol/abstract.mErc20Upgradable.md), [ImErc20Host](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/ImErc20Host.sol/interface.ImErc20Host.md), [ImTokenOperationTypes](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/ImToken.sol/interface.ImTokenOperationTypes.md)

**Author:**
Merge Layers Inc.

Host contract for mErc20 tokens


## State Variables
### acc
Mapping of chain IDs to accumulated amounts


```solidity
mapping(uint32 chainId => Accumulated accumulated) internal acc
```


### allowedCallers
Mapping of allowed callers


```solidity
mapping(address caller => mapping(address target => bool allowed)) public allowedCallers
```


### allowedChains
Mapping of allowed chains


```solidity
mapping(uint32 chainId => bool allowed) public allowedChains
```


### verifier
The ZkVerifier contract


```solidity
IZkVerifier public verifier
```


### gasHelper
The gas fees helper contract


```solidity
IGasFeesHelper public gasHelper
```


### migrator
Migrator address


```solidity
address public migrator
```


### __gap

```solidity
uint256[50] private __gap
```


## Functions
### onlyMigrator

Modifier to restrict access to migrator only


```solidity
modifier onlyMigrator() ;
```

### initialize

Initializes the new money market


```solidity
function initialize(
    address underlying_,
    address operator_,
    address interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    // note: these have to remain as 'memory' to avoid stack-depth issues
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
|`roles_`|`address`|The IRoles address|


### updateAllowedChain

Updates an allowed chain status


```solidity
function updateAllowedChain(uint32 _chainId, bool status_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_chainId`|`uint32`|the chain id|
|`status_`|`bool`|the new status|


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
function mintOrBorrowMigration(bool isMint, uint256 amount, address receiver, address borrower, uint256 minAmount)
    external
    onlyMigrator;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isMint`|`bool`||
|`amount`|`uint256`|The amount of underlying to be accounted for|
|`receiver`|`address`|The address that will receive the mTokens or the underlying in case of borrowing|
|`borrower`|`address`|The address that borrow is executed for|
|`minAmount`|`uint256`|The min amount of underlying to be accounted for|


### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32 dstId) external view returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address for the proof|
|`dstId`|`uint32`|The destination chain identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|dataRoot The proof data root|
|`<none>`|`uint256`|journalHash The proof journal hash|


### _liquidateExternal

Processes a single liquidateExternal call from decoded journal


```solidity
function _liquidateExternal(
    bytes memory singleJournal,
    address userToLiquidate,
    uint256 liquidateAmount,
    address collateral,
    address receiver
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`singleJournal`|`bytes`|Encoded journal entry|
|`userToLiquidate`|`address`|Account to be liquidated|
|`liquidateAmount`|`uint256`|Amount to liquidate|
|`collateral`|`address`|Collateral address to seize|
|`receiver`|`address`|Receiver of seized collateral|


### _mintExternal

Processes a single mintExternal call from decoded journal


```solidity
function _mintExternal(bytes memory singleJournal, uint256 mintAmount, uint256 minAmountOut, address receiver)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`singleJournal`|`bytes`|Encoded journal entry|
|`mintAmount`|`uint256`|Amount to mint|
|`minAmountOut`|`uint256`|Minimum amount out allowed|
|`receiver`|`address`|Receiver address|


### _repayExternal

Processes a single repayExternal call from decoded journal


```solidity
function _repayExternal(bytes memory singleJournal, uint256 repayAmount, address receiver) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`singleJournal`|`bytes`|Encoded journal entry|
|`repayAmount`|`uint256`|Amount to repay|
|`receiver`|`address`|Receiver address|


### _checkOutflow

Validates outflow limits via defender


```solidity
function _checkOutflow(uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount to check|


### _onlyAdminOrRole

Ensures caller is admin or has specific role


```solidity
function _onlyAdminOrRole(bytes32 _role) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_role`|`bytes32`|Role identifier to check|


### _checkProofCall

Performs basic proof call checks


```solidity
function _checkProofCall(uint32 dstChainId, uint32 chainId, address market, address sender) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|Destination chain id|
|`chainId`|`uint32`|Source chain id|
|`market`|`address`|Market address encoded in proof|
|`sender`|`address`|Sender extracted from proof|


### _checkSender

Ensures message sender matches source sender or has permission


```solidity
function _checkSender(address msgSender, address srcSender) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgSender`|`address`|The current msg.sender|
|`srcSender`|`address`|Sender encoded in proof|


### _isAllowedFor

Checks if sender has specified role


```solidity
function _isAllowedFor(address _sender, bytes32 role) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|Address to check|
|`role`|`bytes32`|Role identifier|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if allowed|


### _getChainsManagerRole

Retrieves chains manager role id


```solidity
function _getChainsManagerRole() internal view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Role identifier|


### _getProofForwarderRole

Retrieves proof forwarder role id


```solidity
function _getProofForwarderRole() internal view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Role identifier|


### _getBatchProofForwarderRole

Retrieves batch proof forwarder role id


```solidity
function _getBatchProofForwarderRole() internal view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Role identifier|


### _getSequencerRole

Retrieves sequencer role id


```solidity
function _getSequencerRole() internal view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Role identifier|


### _verifyProof

Verifies proof data and checks inclusion constraints


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|Encoded journal data|
|`seal`|`bytes`|Zk proof seal|


### _decodeJournals

Decodes encoded journals data


```solidity
function _decodeJournals(bytes calldata data) internal pure returns (bytes[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Encoded journal data|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes[]`|Decoded journals array|


## Structs
### Accumulated
Struct for accumulated amounts per chain


```solidity
struct Accumulated {
    mapping(address chain => uint256 amount) inPerChain;
    mapping(address chain => uint256 amount) outPerChain;
}
```

