# MixedPriceOracleV4
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\oracles\MixedPriceOracleV4.sol)

**Inherits:**
[IOracleOperator](/src\interfaces\IOracleOperator.sol\interface.IOracleOperator.md)


## State Variables
### STALENESS_PERIOD

```solidity
uint256 public immutable STALENESS_PERIOD;
```


### configs

```solidity
mapping(string => PriceConfig) public configs;
```


### stalenessPerSymbol

```solidity
mapping(string => uint256) public stalenessPerSymbol;
```


### deltaPerSymbol

```solidity
mapping(string => uint256) public deltaPerSymbol;
```


### maxPriceDelta

```solidity
uint256 public maxPriceDelta = 1.5e3;
```


### PRICE_DELTA_EXP

```solidity
uint256 public constant PRICE_DELTA_EXP = 1e5;
```


### roles

```solidity
IRoles public immutable roles;
```


## Functions
### constructor


```solidity
constructor(string[] memory symbols_, PriceConfig[] memory configs_, address roles_, uint256 stalenessPeriod_);
```

### setStaleness


```solidity
function setStaleness(string memory symbol, uint256 val) external;
```

### setConfig


```solidity
function setConfig(string memory symbol, PriceConfig memory config) external;
```

### setMaxPriceDelta


```solidity
function setMaxPriceDelta(uint256 _delta) external;
```

### setSymbolMaxPriceDelta


```solidity
function setSymbolMaxPriceDelta(uint256 _delta, string calldata _symbol) external;
```

### getPrice


```solidity
function getPrice(address mToken) public view returns (uint256);
```

### getUnderlyingPrice


```solidity
function getUnderlyingPrice(address mToken) external view override returns (uint256);
```

### _getPriceUSD


```solidity
function _getPriceUSD(string memory symbol) internal view returns (uint256);
```

### _getLatestPrice


```solidity
function _getLatestPrice(string memory symbol, PriceConfig memory config) internal view returns (uint256, uint256);
```

### _absDiff


```solidity
function _absDiff(int256 a, int256 b) internal pure returns (uint256);
```

### _getStaleness


```solidity
function _getStaleness(string memory symbol) internal view returns (uint256);
```

## Events
### ConfigSet

```solidity
event ConfigSet(string symbol, PriceConfig config);
```

### StalenessUpdated

```solidity
event StalenessUpdated(string symbol, uint256 val);
```

### PriceDeltaUpdated

```solidity
event PriceDeltaUpdated(uint256 oldVal, uint256 newVal);
```

### PriceSymbolDeltaUpdated

```solidity
event PriceSymbolDeltaUpdated(uint256 oldVal, uint256 newVal, string symbol);
```

## Errors
### MixedPriceOracle_Unauthorized

```solidity
error MixedPriceOracle_Unauthorized();
```

### MixedPriceOracle_ApiV3StalePrice

```solidity
error MixedPriceOracle_ApiV3StalePrice();
```

### MixedPriceOracle_eOracleStalePrice

```solidity
error MixedPriceOracle_eOracleStalePrice();
```

### MixedPriceOracle_InvalidPrice

```solidity
error MixedPriceOracle_InvalidPrice();
```

### MixedPriceOracle_InvalidRound

```solidity
error MixedPriceOracle_InvalidRound();
```

### MixedPriceOracle_InvalidConfig

```solidity
error MixedPriceOracle_InvalidConfig();
```

### MixedPriceOracle_InvalidConfigDecimals

```solidity
error MixedPriceOracle_InvalidConfigDecimals();
```

### MixedPriceOracle_DeltaTooHigh

```solidity
error MixedPriceOracle_DeltaTooHigh();
```

### MixedPriceOracle_MissingFeed

```solidity
error MixedPriceOracle_MissingFeed();
```

## Structs
### PriceConfig

```solidity
struct PriceConfig {
    address api3Feed;
    address eOracleFeed;
    string toSymbol;
    uint256 underlyingDecimals;
}
```

