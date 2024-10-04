# ImTokenMinimal
[Git Source](https://github.com/malda-protocol/malda-lending/blob/00d040411754d9ec62fde1c26b93be292ca3e328/src\interfaces\ImToken.sol)


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

