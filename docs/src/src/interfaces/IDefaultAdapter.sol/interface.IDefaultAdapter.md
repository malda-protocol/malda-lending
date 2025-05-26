# IDefaultAdapter
[Git Source](https://github.com/malda-protocol/malda-lending/blob/157d7bccdcadcb7388d89b00ec47106a82e67e78/src\interfaces\IDefaultAdapter.sol)


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

