# mTokenGateway
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/mToken/extension/mTokenGateway.sol)

**Inherits:**
OwnableUpgradeable, [ImTokenGateway](/src/interfaces/ImTokenGateway.sol/interface.ImTokenGateway.md), [ImTokenOperationTypes](/src/interfaces/ImToken.sol/interface.ImTokenOperationTypes.md), [HypernativeFirewallProtected](/src/libraries/HypernativeFirewallProtected.sol/abstract.HypernativeFirewallProtected.md)

**Title:**
mTokenGateway

**Author:**
Merge Layers Inc.

Gateway contract for mToken operations


## State Variables
### LINEA_CHAIN_ID
Linea chain ID


```solidity
uint32 private constant LINEA_CHAIN_ID = 59144
```


### rolesOperator
Roles


```solidity
IRoles public rolesOperator
```


### blacklistOperator
Blacklist operator


```solidity
IBlacklister public blacklistOperator
```


### verifier
The ZkVerifier contract


```solidity
IZkVerifier public verifier
```


### paused
Mapping of operation types to pause status


```solidity
mapping(OperationType operationType => bool paused) public paused
```


### underlying
Returns the address of the underlying token


```solidity
address public underlying
```


### accAmountIn
Mapping of accumulated amounts in


```solidity
mapping(address account => uint256 amount) public accAmountIn
```


### accAmountOut
Mapping of accumulated amounts out


```solidity
mapping(address account => uint256 amount) public accAmountOut
```


### allowedCallers
Mapping of allowed callers


```solidity
mapping(address caller => mapping(address target => bool allowed)) public allowedCallers
```


### userWhitelisted
Mapping of whitelisted users


```solidity
mapping(address user => bool whitelisted) public userWhitelisted
```


### whitelistEnabled
Whether whitelist is enabled


```solidity
bool public whitelistEnabled
```


### gasFee
Gas fee required for `supplyOnHost`


```solidity
uint256 public gasFee
```


### __gap

```solidity
uint256[50] private __gap
```


## Functions
### notPaused

Modifier to restrict access to only allowed users


```solidity
modifier notPaused(OperationType _type) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_type`|`OperationType`|The operation type|


### onlyAllowedUser

Modifier to restrict access to only allowed users


```solidity
modifier onlyAllowedUser(address user) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|


### ifNotBlacklisted

Modifier to restrict access to only not blacklisted users


```solidity
modifier ifNotBlacklisted(address user) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|


### liquidateChecks

Modifier to check liquidate conditions


```solidity
modifier liquidateChecks() ;
```

### constructor

Disables initializers on implementation

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### initialize

Initializes the gateway


```solidity
function initialize(
    address payable _owner,
    address _underlying,
    address _roles,
    address _blacklister,
    address zkVerifier_
) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address payable`|Owner address|
|`_underlying`|`address`|Underlying token|
|`_roles`|`address`|Roles contract|
|`_blacklister`|`address`|Blacklister contract|
|`zkVerifier_`|`address`|ZK verifier|


### initFirewall

Initializes the firewall configuration


```solidity
function initFirewall(address _firewall) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_firewall`|`address`|Firewall address to set|


### setBlacklister

Sets the blacklister contract


```solidity
function setBlacklister(address _blacklister) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_blacklister`|`address`|Address of the blacklister|


### setWhitelistedUser

Sets user whitelist status


```solidity
function setWhitelistedUser(address user, bool state) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`state`|`bool`|The new state|


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


```solidity
function setPaused(OperationType _type, bool state) external override;
```

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
    ifNotBlacklisted(receiver)
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The supplied amount|
|`receiver`|`address`|The receiver address|
|`lineaSelector`|`bytes4`|The method selector to be called on Linea by our relayer. If empty, user has to submit it|


### liquidate

Liquidate a user


```solidity
function liquidate(address userToLiquidate, uint256 liquidateAmount, address collateral, address receiver)
    external
    payable
    override
    liquidateChecks
    ifNotBlacklisted(receiver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`userToLiquidate`|`address`|The user to liquidate|
|`liquidateAmount`|`uint256`|The amount to liquidate|
|`collateral`|`address`|The collateral address|
|`receiver`|`address`|The receiver address|


### outHere

Extract tokens


```solidity
function outHere(bytes calldata journalData, bytes calldata seal, uint256[] calldata amounts, address receiver)
    external
    notPaused(OperationType.AmountOutHere)
    ifNotBlacklisted(msg.sender)
    ifNotBlacklisted(receiver)
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|The supplied journal|
|`seal`|`bytes`|The seal address|
|`amounts`|`uint256[]`|The amounts to withdraw for each journal|
|`receiver`|`address`|The receiver address|


### isPaused


```solidity
function isPaused(OperationType _type) external view returns (bool);
```

### getProofData

Returns the proof data journal


```solidity
function getProofData(address user, uint32) external view returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|
|`<none>`|`uint32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|dataRoot The proof data root|
|`<none>`|`uint256`|journalHash The proof journal hash|


### firewallRegister

Registers an account in the firewall


```solidity
function firewallRegister(address _account) public override(HypernativeFirewallProtected);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Account to register|


### _takeIn

Handles inbound transfers and accounting


```solidity
function _takeIn(address asset, uint256 amount, address receiver) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address|
|`amount`|`uint256`|Amount to transfer|
|`receiver`|`address`|Receiver address|


### _outHere

Processes an outgoing transfer based on journal data


```solidity
function _outHere(bytes memory journalData, uint256 amount, address receiver) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|Encoded journal payload|
|`amount`|`uint256`|Amount to transfer|
|`receiver`|`address`|Receiver address override|


### _verifyProof

Verifies proof data and inclusion constraints


```solidity
function _verifyProof(bytes calldata journalData, bytes calldata seal) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`journalData`|`bytes`|Encoded journals|
|`seal`|`bytes`|Proof seal data|


### _checkSender

Validates sender permissions for proof forwarding


```solidity
function _checkSender(address msgSender, address srcSender) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgSender`|`address`|Caller address|
|`srcSender`|`address`|Source sender encoded in journal|


### _getSequencerRole

Returns sequencer role identifier


```solidity
function _getSequencerRole() private view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Role id|


### _getBatchProofForwarderRole

Returns batch proof forwarder role identifier


```solidity
function _getBatchProofForwarderRole() private view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Role id|


### _getProofForwarderRole

Returns proof forwarder role identifier


```solidity
function _getProofForwarderRole() private view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Role id|


### _isAllowedFor

Checks if sender has a specific role


```solidity
function _isAllowedFor(address _sender, bytes32 role) private view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sender`|`address`|Sender address|
|`role`|`bytes32`|Role to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if allowed|


