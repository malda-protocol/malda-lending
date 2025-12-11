# MixedPriceOracleV4
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/oracles/MixedPriceOracleV4.sol)

**Inherits:**
[IOracleOperator](/src/interfaces/IOracleOperator.sol/interface.IOracleOperator.md)

**Title:**
MixedPriceOracleV4

**Author:**
Merge Layers Inc.

Mixed price oracle using dual feeds and staleness checks


## State Variables
### PRICE_DELTA_EXP
Price delta exponent (basis points denominator)


```solidity
uint256 public constant PRICE_DELTA_EXP = 1e5
```


### STALENESS_PERIOD
Default staleness period applied to feeds


```solidity
uint256 public immutable STALENESS_PERIOD
```


### ROLES
Roles contract reference


```solidity
IRoles public immutable ROLES
```


### configs
Mapping of symbols to price configs


```solidity
mapping(string symbol => PriceConfig config) public configs
```


### stalenessPerSymbol
Mapping of symbols to custom staleness


```solidity
mapping(string symbol => uint256 staleness) public stalenessPerSymbol
```


### deltaPerSymbol
Mapping of symbols to custom price deltas


```solidity
mapping(string symbol => uint256 delta) public deltaPerSymbol
```


### maxPriceDelta
Maximum allowed delta in basis points for price comparison


```solidity
uint256 public maxPriceDelta = 1.5e3
```


## Functions
### constructor

Initializes the oracle with configs, roles, and staleness


```solidity
constructor(string[] memory symbols_, PriceConfig[] memory configs_, address roles_, uint256 stalenessPeriod_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbols_`|`string[]`|Symbols being configured|
|`configs_`|`PriceConfig[]`|Price configs for symbols|
|`roles_`|`address`|Roles contract address|
|`stalenessPeriod_`|`uint256`|Default staleness period|


### setStaleness

Sets a custom staleness for a symbol


```solidity
function setStaleness(string calldata symbol, uint256 val) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol to update|
|`val`|`uint256`|New staleness value|


### setConfig

Sets price configuration for a symbol


```solidity
function setConfig(string calldata symbol, PriceConfig calldata config) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol to configure|
|`config`|`PriceConfig`|Price configuration|


### setMaxPriceDelta

Sets maximum allowed price delta


```solidity
function setMaxPriceDelta(uint256 _delta) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_delta`|`uint256`|New max delta in basis points|


### setSymbolMaxPriceDelta

Sets maximum price delta for a specific symbol


```solidity
function setSymbolMaxPriceDelta(uint256 _delta, string calldata _symbol) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_delta`|`uint256`|New delta in basis points|
|`_symbol`|`string`|Symbol to update|


### getPrice

Returns price for an mToken


```solidity
function getPrice(address mToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Address of the mToken|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Price denominated in USD with 18 decimals|


### getUnderlyingPrice

Returns underlying price for an mToken


```solidity
function getUnderlyingPrice(address mToken) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Address of the mToken|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Price denominated in USD with 18 decimals adjusted for underlying decimals|


### _getPriceUSD

Returns USD price for a symbol using dual feeds


```solidity
function _getPriceUSD(string memory symbol) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Token symbol|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|USD price with 18 decimals|


### _getApi3Price

Retrieves price and last update from API3 feed


```solidity
function _getApi3Price(string memory symbol) internal view returns (uint256 price, uint256 lastUpdate);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Token symbol|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Price scaled to 18 decimals|
|`lastUpdate`|`uint256`|Timestamp of last update|


### _geteOraclePrice

Retrieves price and last update from eOracle feed


```solidity
function _geteOraclePrice(string memory symbol) internal view returns (uint256 price, uint256 lastUpdate);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Token symbol|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Price scaled to 18 decimals|
|`lastUpdate`|`uint256`|Timestamp of last update|


### _isFresh

Checks if price data is fresh


```solidity
function _isFresh(uint256 updatedAt, uint256 staleness) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`updatedAt`|`uint256`|Timestamp of last update|
|`staleness`|`uint256`|Allowed staleness threshold|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if data is within staleness window|


### _getStaleness

Returns staleness for a symbol or default


```solidity
function _getStaleness(string memory symbol) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Token symbol|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Staleness period in seconds|


### _absDiff

Absolute difference between two int256 values


```solidity
function _absDiff(int256 a, int256 b) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`a`|`int256`|First value|
|`b`|`int256`|Second value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Absolute difference as uint256|


## Events
### ConfigSet
Emitted when a config is set for a symbol


```solidity
event ConfigSet(string symbol, PriceConfig config);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol being configured|
|`config`|`PriceConfig`|Price config stored|

### StalenessUpdated
Emitted when staleness is updated for a symbol


```solidity
event StalenessUpdated(string symbol, uint256 val);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol being updated|
|`val`|`uint256`|New staleness period|

### PriceDeltaUpdated
Emitted when global price delta is updated


```solidity
event PriceDeltaUpdated(uint256 oldVal, uint256 newVal);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldVal`|`uint256`|Previous delta value|
|`newVal`|`uint256`|New delta value|

### PriceSymbolDeltaUpdated
Emitted when symbol price delta is updated


```solidity
event PriceSymbolDeltaUpdated(uint256 oldVal, uint256 newVal, string symbol);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldVal`|`uint256`|Previous delta|
|`newVal`|`uint256`|New delta|
|`symbol`|`string`|Symbol affected|

## Errors
### MixedPriceOracle_Unauthorized
Error thrown when caller is unauthorized


```solidity
error MixedPriceOracle_Unauthorized();
```

### MixedPriceOracle_ApiV3StalePrice
Error thrown when API3 feed price is stale


```solidity
error MixedPriceOracle_ApiV3StalePrice();
```

### MixedPriceOracle_eOracleStalePrice
Error thrown when eOracle feed price is stale


```solidity
error MixedPriceOracle_eOracleStalePrice();
```

### MixedPriceOracle_InvalidPrice
Error thrown when price returned is invalid


```solidity
error MixedPriceOracle_InvalidPrice();
```

### MixedPriceOracle_InvalidConfig
Error thrown when provided config is invalid


```solidity
error MixedPriceOracle_InvalidConfig();
```

### MixedPriceOracle_DeltaTooHigh
Error thrown when delta exceeds allowed max


```solidity
error MixedPriceOracle_DeltaTooHigh();
```

### MixedPriceOracle_MissingFeed
Error thrown when required feed is missing


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

