# ImTokenMinimal
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/ImToken.sol)

**Title:**
ImTokenMinimal

**Author:**
Merge Layers Inc.

Minimal mToken view interface


## Functions
### name

EIP-20 token name for this token


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|tokenName The token name|


### symbol

EIP-20 token symbol for this token


```solidity
function symbol() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|tokenSymbol The token symbol|


### decimals

EIP-20 token decimals for this token


```solidity
function decimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|tokenDecimals The token decimals|


### totalSupply

Returns the value of tokens in existence.


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|supply Total token supply|


### totalUnderlying

Returns the amount of underlying tokens


```solidity
function totalUnderlying() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|underlyingAmount Total underlying amount|


### balanceOf

Returns the value of tokens owned by `account`.


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to check for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|balance Token balance of account|


### underlying

Returns the underlying address


```solidity
function underlying() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|underlyingToken The underlying token address|


