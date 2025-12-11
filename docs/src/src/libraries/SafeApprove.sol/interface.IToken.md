# IToken
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/libraries/SafeApprove.sol)

**Title:**
Minimal ERC20 approve interface

**Author:**
Merge Layers Inc.

Exposes approve to perform safe allowance updates


## Functions
### approve

Approves spender for an allowance amount


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|Address allowed to spend|
|`amount`|`uint256`|Allowance amount|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success True if approve succeeded|


