# IToken
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/libraries/SafeApprove.sol)

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


