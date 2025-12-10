# IAcrossReceiverV3
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/interfaces/external/across/IAcrossReceiverV3.sol)


## Functions
### handleV3AcrossMessage

handles AcrossV3 SpokePool message


```solidity
function handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes memory message) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenSent`|`address`|the token address received|
|`amount`|`uint256`|the token amount|
|`relayer`|`address`|the relayer submitting the message (unused)|
|`message`|`bytes`|the custom message sent from source|


