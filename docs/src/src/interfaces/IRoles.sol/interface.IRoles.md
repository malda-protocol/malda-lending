# IRoles
[Git Source](https://github.com/malda-protocol/malda-lending/blob/00d040411754d9ec62fde1c26b93be292ca3e328/src\interfaces\IRoles.sol)


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


