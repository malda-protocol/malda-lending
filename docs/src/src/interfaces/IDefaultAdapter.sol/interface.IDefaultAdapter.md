# IDefaultAdapter
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/interfaces/IDefaultAdapter.sol)

**Author:**
Merge Layers Inc.

Default price adapter interface used for oracle feeds


## Functions
### decimals

Returns the decimals for the price feed


```solidity
function decimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|decimalsCount Number of decimals|


### latestRoundData

Returns the latest round data from the feed


```solidity
function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`roundId`|`uint80`|Round identifier|
|`answer`|`int256`|Feed answer|
|`startedAt`|`uint256`|Round start timestamp|
|`updatedAt`|`uint256`|Round update timestamp|
|`answeredInRound`|`uint80`|The round in which the answer was computed|


### latestAnswer

Returns the latest answer


```solidity
function latestAnswer() external view returns (int256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`int256`|answer Latest feed answer|


### latestTimestamp

Returns the latest timestamp


```solidity
function latestTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|timestamp Latest update timestamp|


## Structs
### PriceConfig

```solidity
struct PriceConfig {
    address defaultFeed; // chainlink & eOracle
    string toSymbol;
    uint256 underlyingDecimals;
}
```

