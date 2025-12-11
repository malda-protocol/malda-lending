# SafeApprove
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/libraries/SafeApprove.sol)

**Title:**
SafeApprove

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

