# IDefaultAdapter
[Git Source](https://github.com/malda-protocol/malda-lending/blob/413dc9221d099e8e0b7a9a3f94769f4666aaf31b/src\interfaces\IDefaultAdapter.sol)


## Functions
### decimals


```solidity
function decimals() external view returns (uint8);
```

### latestRoundData


```solidity
function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
```

### latestAnswer


```solidity
function latestAnswer() external view returns (int256);
```

### latestTimestamp


```solidity
function latestTimestamp() external view returns (uint256);
```

## Structs
### PriceConfig

```solidity
struct PriceConfig {
    address defaultFeed;
    string toSymbol;
    uint256 underlyingDecimals;
}
```

