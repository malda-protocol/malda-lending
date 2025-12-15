# IEverclearSpoke
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\external\everclear\IEverclearSpoke.sol)


## Functions
### newIntent

Creates a new intent


```solidity
function newIntent(
    uint32[] memory _destinations,
    address _receiver,
    address _inputAsset,
    address _outputAsset,
    uint256 _amount,
    uint24 _maxFee,
    uint48 _ttl,
    bytes calldata _data
) external returns (bytes32 _intentId, Intent memory _intent);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_destinations`|`uint32[]`|The possible destination chains of the intent|
|`_receiver`|`address`|The destinantion address of the intent|
|`_inputAsset`|`address`|The asset address on origin|
|`_outputAsset`|`address`|The asset address on destination|
|`_amount`|`uint256`|The amount of the asset|
|`_maxFee`|`uint24`|The maximum fee that can be taken by solvers|
|`_ttl`|`uint48`|The time to live of the intent|
|`_data`|`bytes`|The data of the intent|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_intentId`|`bytes32`|The ID of the intent|
|`_intent`|`Intent`|The intent object|


## Structs
### Intent

```solidity
struct Intent {
    uint256 val;
}
```

