# IRoles
[Git Source](https://github.com/malda-protocol/malda-lending/blob/b62e113034d94e880ebb241b8fad49eb27118646/src\interfaces\IRoles.sol)


## Functions
### allowedFor

returns allowance status for a contract and a role


```solidity
function allowedFor(address _contract, bytes32 _role) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_contract`|`address`|the contract address|
|`_role`|`bytes32`|the bytes32 role|


