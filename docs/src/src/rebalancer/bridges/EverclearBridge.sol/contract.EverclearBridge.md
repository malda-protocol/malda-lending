# EverclearBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\rebalancer\bridges\EverclearBridge.sol)

**Inherits:**
[BaseBridge](/src\rebalancer\bridges\BaseBridge.sol\abstract.BaseBridge.md), [IBridge](/src\interfaces\IBridge.sol\interface.IBridge.md)


## State Variables
### everclearFeeAdapter

```solidity
IFeeAdapter public everclearFeeAdapter;
```


## Functions
### constructor


```solidity
constructor(address _roles, address _feeAdapter) BaseBridge(_roles);
```

### getFee

computes fee for bridge operation


```solidity
function getFee(uint32, bytes memory, bytes memory) external pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`||
|`<none>`|`bytes`||
|`<none>`|`bytes`||


### sendMsg


```solidity
function sendMsg(
    uint256 _extractedAmount,
    address _market,
    uint32 _dstChainId,
    address _token,
    bytes memory _message,
    bytes memory
) external payable onlyRebalancer;
```

### _decodeIntent


```solidity
function _decodeIntent(bytes memory message) internal pure returns (IntentParams memory);
```

## Events
### MsgSent

```solidity
event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);
```

### RebalancingReturnedToMarket

```solidity
event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);
```

## Errors
### Everclear_TokenMismatch

```solidity
error Everclear_TokenMismatch();
```

### Everclear_NotImplemented

```solidity
error Everclear_NotImplemented();
```

### Everclear_AddressNotValid

```solidity
error Everclear_AddressNotValid();
```

### Everclear_DestinationNotValid

```solidity
error Everclear_DestinationNotValid();
```

### Everclear_DestinationsLengthMismatch

```solidity
error Everclear_DestinationsLengthMismatch();
```

## Structs
### IntentParams

```solidity
struct IntentParams {
    uint32[] destinations;
    bytes32 receiver;
    address inputAsset;
    bytes32 outputAsset;
    uint256 amount;
    uint24 maxFee;
    uint48 ttl;
    bytes data;
    IFeeAdapter.FeeParams feeParams;
}
```

