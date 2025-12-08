# IWrappedNative
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/utils/WrapAndSupply.sol)

**Author:**
Malda Protocol

Minimal interface used to wrap/unwrap native tokens (e.g., WETH)


## Functions
### deposit

Wraps native ETH into WETH


```solidity
function deposit() external payable;
```

### transfer

Transfers wrapped native tokens


```solidity
function transfer(address to, uint256 value) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Receiver address|
|`value`|`uint256`|Amount to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the transfer succeeded|


### withdraw

Unwraps wrapped native tokens back to the native coin


```solidity
function withdraw(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount to unwrap|


