# DefaultGasHelper
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\oracles\gas\DefaultGasHelper.sol)

**Inherits:**
Ownable


## State Variables
### gasFees

```solidity
mapping(uint32 => uint256) public gasFees;
```


## Functions
### constructor


```solidity
constructor(address _owner) Ownable(_owner);
```

### setGasFee

Sets the gas fee


```solidity
function setGasFee(uint32 dstChainId, uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dstChainId`|`uint32`|the destination chain id|
|`amount`|`uint256`|the gas fee amount|


## Events
### GasFeeUpdated

```solidity
event GasFeeUpdated(uint32 indexed dstChainid, uint256 amount);
```

