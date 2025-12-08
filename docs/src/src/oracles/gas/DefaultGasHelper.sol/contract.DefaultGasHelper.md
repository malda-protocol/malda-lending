# DefaultGasHelper
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/oracles/gas/DefaultGasHelper.sol)

**Inherits:**
Ownable

**Author:**
Merge Layers Inc.

Helper contract for managing gas fees


## State Variables
### gasFees
Mapping of chain IDs to gas fees


```solidity
mapping(uint32 chainId => uint256 fee) public gasFees
```


## Functions
### constructor

Constructor


```solidity
constructor(address owner_) Ownable(owner_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`|The owner address|


### setGasFee

Sets the gas fee


```solidity
function setGasFee(uint32 dstChainId, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|The destination chain id|
|`amount`|`uint256`|The gas fee amount|


## Events
### GasFeeUpdated
Event emitted when gas fee is updated


```solidity
event GasFeeUpdated(uint32 indexed dstChainId, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|The destination chain ID|
|`amount`|`uint256`|The gas fee amount|

