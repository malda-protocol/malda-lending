# MixedPriceOracleV3
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/oracles/MixedPriceOracleV3.sol)

**Inherits:**
[IOracleOperator](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/IOracleOperator.sol/interface.IOracleOperator.md)

**Author:**
Merge Layers Inc.

Mixed price oracle contract


## State Variables
### STALENESS_PERIOD
Staleness period


```solidity
uint256 public immutable STALENESS_PERIOD
```


### ROLES
Roles contract


```solidity
IRoles public immutable ROLES
```


### configs
Mapping of symbols to price configs


```solidity
mapping(string symbol => IDefaultAdapter.PriceConfig config) public configs
```


### stalenessPerSymbol
Mapping of symbols to staleness periods


```solidity
mapping(string symbol => uint256 staleness) public stalenessPerSymbol
```


## Functions
### constructor

Initializes the oracle with symbols, configs, roles, and default staleness


```solidity
constructor(
    string[] memory symbols_,
    IDefaultAdapter.PriceConfig[] memory configs_,
    address roles_,
    uint256 stalenessPeriod_
) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbols_`|`string[]`|Array of token symbols|
|`configs_`|`IDefaultAdapter.PriceConfig[]`|Array of price configs for symbols|
|`roles_`|`address`|Roles contract address|
|`stalenessPeriod_`|`uint256`|Default staleness period|


### setStaleness

Sets a custom staleness period for a symbol


```solidity
function setStaleness(string calldata symbol, uint256 val) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol to update|
|`val`|`uint256`|New staleness value|


### setConfig

Sets a price configuration for a symbol


```solidity
function setConfig(string calldata symbol, IDefaultAdapter.PriceConfig calldata config) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol to configure|
|`config`|`IDefaultAdapter.PriceConfig`|Price configuration|


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


### getPrice

Returns price for an mToken


```solidity
function getPrice(address mToken) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Address of the mToken|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Price denominated in USD with 18 decimals|


### _getPriceUSD

Returns the USD price for a symbol


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
|`<none>`|`uint256`|price Price denominated in USD with 18 decimals|


### _getLatestPrice

Fetches the latest price from configured feeds


```solidity
function _getLatestPrice(string memory symbol, IDefaultAdapter.PriceConfig memory config)
    internal
    view
    returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Token symbol|
|`config`|`IDefaultAdapter.PriceConfig`|Price configuration for the symbol|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price Latest price from feed|
|`<none>`|`uint256`|decimals Decimals returned by the feed|


### _getStaleness

Returns staleness for a symbol or default if not set


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


## Events
### ConfigSet
Emitted when a configuration is set for a symbol


```solidity
event ConfigSet(string symbol, IDefaultAdapter.PriceConfig config);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol being configured|
|`config`|`IDefaultAdapter.PriceConfig`|Price configuration applied|

### StalenessUpdated
Emitted when staleness is updated for a symbol


```solidity
event StalenessUpdated(string symbol, uint256 val);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|Symbol being updated|
|`val`|`uint256`|New staleness value|

## Errors
### MixedPriceOracle_Unauthorized
Error thrown when caller lacks required role


```solidity
error MixedPriceOracle_Unauthorized();
```

### MixedPriceOracle_StalePrice
Error thrown when price is stale


```solidity
error MixedPriceOracle_StalePrice();
```

### MixedPriceOracle_InvalidPrice
Error thrown when price returned is invalid


```solidity
error MixedPriceOracle_InvalidPrice();
```

### MixedPriceOracle_InvalidRound
Error thrown when price round is invalid


```solidity
error MixedPriceOracle_InvalidRound();
```

### MixedPriceOracle_InvalidConfig
Error thrown when configuration is invalid


```solidity
error MixedPriceOracle_InvalidConfig();
```

