# MockTokensBridge
[Git Source](https://github.com/malda-protocol/malda-lending/blob/01abcfb9040cf303f2a5fc706b3c3af752e0b27a/src\rebalancer\bridges\MockTokensBridge.sol)

**Inherits:**
[BaseBridge](/src\rebalancer\bridges\BaseBridge.sol\abstract.BaseBridge.md), [IBridge](/src\interfaces\IBridge.sol\interface.IBridge.md), ReentrancyGuard


## State Variables
### tokens

```solidity
address[] tokens;
```


## Functions
### constructor


```solidity
constructor(address _roles, address[] memory _tokens) BaseBridge(_roles);
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

### triggerMintTest


```solidity
function triggerMintTest(address _market, address _token, uint32 _dstChainId, uint256 _amount)
    external
    onlyRebalancer;
```

## Events
### MockTokensBridgeMintAndBurn

```solidity
event MockTokensBridgeMintAndBurn(
    address indexed _market, address indexed _token, uint256 amount, uint32 crtChainId, uint32 dstChainId
);
```

