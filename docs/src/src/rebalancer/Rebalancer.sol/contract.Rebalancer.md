# Rebalancer
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\rebalancer\Rebalancer.sol)

**Inherits:**
[IRebalancer](/src\interfaces\IRebalancer.sol\interface.IRebalancer.md)


## State Variables
### roles

```solidity
IRoles public roles;
```


### nonce

```solidity
uint256 public nonce;
```


### logs

```solidity
mapping(uint32 => mapping(uint256 => Msg)) public logs;
```


### whitelistedBridges

```solidity
mapping(address => bool) public whitelistedBridges;
```


### whitelistedDestinations

```solidity
mapping(uint32 => bool) public whitelistedDestinations;
```


### allowedList

```solidity
mapping(address => bool) public allowedList;
```


### saveAddress

```solidity
address public saveAddress;
```


### maxTransferSizes

```solidity
mapping(uint32 => mapping(address => uint256)) public maxTransferSizes;
```


### minTransferSizes

```solidity
mapping(uint32 => mapping(address => uint256)) public minTransferSizes;
```


### currentTransferSize

```solidity
mapping(uint32 => mapping(address => TransferInfo)) public currentTransferSize;
```


### transferTimeWindow

```solidity
uint256 public transferTimeWindow;
```


## Functions
### constructor


```solidity
constructor(address _roles, address _saveAddress);
```

### setAllowList


```solidity
function setAllowList(address[] calldata list, bool status) external;
```

### setWhitelistedBridgeStatus


```solidity
function setWhitelistedBridgeStatus(address _bridge, bool _status) external;
```

### setWhitelistedDestination


```solidity
function setWhitelistedDestination(uint32 _dstId, bool _status) external;
```

### saveEth


```solidity
function saveEth() external;
```

### setMinTransferSize


```solidity
function setMinTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external;
```

### setMaxTransferSize


```solidity
function setMaxTransferSize(uint32 _dstChainId, address _token, uint256 _limit) external;
```

### isBridgeWhitelisted

returns if a bridge implementation is whitelisted


```solidity
function isBridgeWhitelisted(address bridge) external view returns (bool);
```

### isDestinationWhitelisted

returns if a destination is whitelisted


```solidity
function isDestinationWhitelisted(uint32 dstId) external view returns (bool);
```

### sendMsg

sends a bridge message


```solidity
function sendMsg(address _bridge, address _market, uint256 _amount, Msg calldata _msg) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_bridge`|`address`||
|`_market`|`address`|the market to rebalance from address|
|`_amount`|`uint256`|the amount to rebalance|
|`_msg`|`Msg`||


## Structs
### TransferInfo

```solidity
struct TransferInfo {
    uint256 size;
    uint256 timestamp;
}
```

