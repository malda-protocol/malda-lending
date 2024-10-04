# ImTokenMinimal
[Git Source](https://github.com/malda-protocol/malda-lending/blob/b62e113034d94e880ebb241b8fad49eb27118646/src\interfaces\ImToken.sol)


## Functions
### balanceOf

Returns the value of tokens owned by `account`.


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to check for|


### symbol

*Returns the symbol of the token, usually a shorter version of the
name.*


```solidity
function symbol() external view returns (string memory);
```

### totalSupply

Returns the value of tokens in existence.


```solidity
function totalSupply() external view returns (uint256);
```

