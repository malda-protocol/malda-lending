# SafeApprove
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/libraries/SafeApprove.sol)

**Author:**
Merge Layers Inc.

Library for safely setting ERC20 approvals


## Functions
### safeApprove

Safely sets allowance to zero then desired value


```solidity
function safeApprove(address token, address to, uint256 value) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token to approve|
|`to`|`address`|Spender address|
|`value`|`uint256`|New allowance to set|


## Errors
### SafeApprove_NoContract
Thrown when target is not a contract


```solidity
error SafeApprove_NoContract();
```

### SafeApprove_Failed
Thrown when an approve call fails


```solidity
error SafeApprove_Failed();
```

