# Rebalancer
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/rebalancer/Rebalancer.sol)

**Inherits:**
[IRebalancer](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/IRebalancer.sol/interface.IRebalancer.md), [HypernativeFirewallProtected](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/libraries/HypernativeFirewallProtected.sol/abstract.HypernativeFirewallProtected.md), ReentrancyGuard

**Author:**
Malda Protocol

Manages bridge interactions and transfer size limits for cross-chain rebalancing.


## State Variables
### roles
Roles contract used for access control


```solidity
IRoles public roles
```


### nonce
Incremental nonce used for logging messages


```solidity
uint256 public nonce
```


### logs
Sent messages indexed by destination chain and nonce


```solidity
mapping(uint32 chainId => mapping(uint256 nonce => Msg message)) public logs
```


### whitelistedBridges
Bridge whitelist status


```solidity
mapping(address bridge => bool whitelisted) public whitelistedBridges
```


### allowedTokensPerBridge
Allowed tokens per bridge


```solidity
mapping(address bridge => mapping(address token => bool allowed)) public allowedTokensPerBridge
```


### whitelistedDestinations
Destination chain whitelist status


```solidity
mapping(uint32 dstChainId => bool whitelisted) public whitelistedDestinations
```


### allowedList
Markets allowed for rebalancing


```solidity
mapping(address market => bool allowed) public allowedList
```


### admin
Admin address with elevated permissions


```solidity
address public admin
```


### saveAddress
Address used to sweep saved assets


```solidity
address public saveAddress
```


### maxTransferSizes
Per-chain token maximum transfer size


```solidity
mapping(uint32 dstChainId => mapping(address token => uint256 maxSize)) public maxTransferSizes
```


### minTransferSizes
Per-chain token minimum transfer size


```solidity
mapping(uint32 dstChainId => mapping(address token => uint256 minSize)) public minTransferSizes
```


### currentTransferSize
Rolling transfer info for size-window enforcement


```solidity
mapping(uint32 dstChainId => mapping(address token => TransferInfo transferInfo)) public currentTransferSize
```


### whitelistedMarkets
Market whitelist status


```solidity
mapping(address market => bool whitelisted) public whitelistedMarkets
```


### transferTimeWindow
Duration of the rolling transfer size window


```solidity
uint256 public transferTimeWindow
```


## Functions
### constructor

Initializes the Rebalancer


```solidity
constructor(address _roles, address _saveAddress, address _admin) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|Roles contract|
|`_saveAddress`|`address`|Address to sweep saved assets to|
|`_admin`|`address`|Admin address|


### setAllowedTokens

Set allowed tokens for a bridge


```solidity
function setAllowedTokens(address bridge, address[] calldata tokens, bool status) external onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|Bridge address|
|`tokens`|`address[]`|Token list to allow/disallow|
|`status`|`bool`|Allowance status|


### setMarketStatus

Batch whitelist/unwhitelist markets


```solidity
function setMarketStatus(address[] calldata list, bool status) external onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`list`|`address[]`|Market addresses|
|`status`|`bool`|Whitelist status|


### setAllowList

Batch set allow-list status for markets


```solidity
function setAllowList(address[] calldata list, bool status) external onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`list`|`address[]`|Market addresses|
|`status`|`bool`|Allow list status|


### setWhitelistedBridgeStatus

Set whitelist status for a bridge


```solidity
function setWhitelistedBridgeStatus(address _bridge, bool status_) external onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bridge`|`address`|Bridge address|
|`status_`|`bool`|Whitelist status|


### setWhitelistedDestination

Set whitelist status for a destination chain


```solidity
function setWhitelistedDestination(uint32 _dstId, bool status_) external onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstId`|`uint32`|Destination chain id|
|`status_`|`bool`|Whitelist status|


### saveEth

Sweep native ETH to the configured save address


```solidity
function saveEth() external onlyFirewallApproved;
```

### saveTokens

Sweep stray tokens to the given market


```solidity
function saveTokens(address token, address market) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to sweep|
|`market`|`address`|Market to receive tokens|


### setMinTransferSize

Set minimum transfer size for a destination/token


```solidity
function setMinTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstChainId`|`uint32`|Destination chain id|
|`_token`|`address`|Token address|
|`_limit`|`uint256`|Minimum size|


### setMaxTransferSize

Set maximum transfer size for a destination/token


```solidity
function setMaxTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstChainId`|`uint32`|Destination chain id|
|`_token`|`address`|Token address|
|`_limit`|`uint256`|Maximum size|


### sendMsg

Sends a bridge message


```solidity
function sendMsg(address _bridge, address _market, uint256 _amount, Msg calldata _msg)
    external
    payable
    onlyFirewallApproved
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bridge`|`address`||
|`_market`|`address`|The market to rebalance from address|
|`_amount`|`uint256`|The amount to rebalance|
|`_msg`|`Msg`|The message data|


### isMarketWhitelisted

Returns if a market is whitelisted


```solidity
function isMarketWhitelisted(address market) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|Market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|whitelisted True if whitelisted|


### isBridgeWhitelisted

Returns if a bridge implementation is whitelisted


```solidity
function isBridgeWhitelisted(address bridge) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bridge`|`address`|Bridge address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|whitelisted True if whitelisted|


### isDestinationWhitelisted

Returns if a destination is whitelisted


```solidity
function isDestinationWhitelisted(uint32 dstId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstId`|`uint32`|Destination chain ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|whitelisted True if whitelisted|


### firewallRegister

Registers an account with the firewall


```solidity
function firewallRegister(address _account) public override(HypernativeFirewallProtected);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Account to register|


## Structs
### TransferInfo

```solidity
struct TransferInfo {
    uint256 size;
    uint256 timestamp;
}
```

