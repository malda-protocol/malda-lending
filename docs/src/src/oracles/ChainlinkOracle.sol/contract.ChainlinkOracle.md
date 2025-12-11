# ChainlinkOracle
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/oracles/ChainlinkOracle.sol)

**Inherits:**
[IOracleOperator](/src/interfaces/IOracleOperator.sol/interface.IOracleOperator.md)

**Title:**
ChainlinkOracle

**Author:**
Merge Layers Inc.

Oracle contract using Chainlink price feeds


## State Variables
### DECIMALS
Number of decimals for price


```solidity
uint8 public constant DECIMALS = 18
```


### priceFeeds
Mapping of symbols to price feeds


```solidity
mapping(string symbol => IAggregatorV3 feed) public priceFeeds
```


### baseUnits
Mapping of symbols to base units


```solidity
mapping(string symbol => uint256 units) public baseUnits
```


## Functions
### constructor

Constructor


```solidity
constructor(string[] memory symbols_, IAggregatorV3[] memory feeds_, uint256[] memory baseUnits_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbols_`|`string[]`|Array of symbols|
|`feeds_`|`IAggregatorV3[]`|Array of price feeds|
|`baseUnits_`|`uint256[]`|Array of base units|


### getPrice

Get the price of a mToken asset


```solidity
function getPrice(address mToken) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The mToken to get the price of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price The underlying asset price mantissa (scaled by 1e18). Zero means unavailable.|


### getUnderlyingPrice

Get the underlying price of a mToken asset


```solidity
function getUnderlyingPrice(address mToken) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The mToken to get the underlying price of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price The underlying asset price mantissa (scaled by 1e18). Zero means unavailable.|


### _getLatestPrice

Get the latest price for a symbol


```solidity
function _getLatestPrice(string memory symbol) internal view returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`symbol`|`string`|The symbol to get price for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|answer The price|
|`<none>`|`uint256`|updatedAt The timestamp when the price was last updated|


## Errors
### ChainlinkOracle_NoPriceFeed
Error thrown when no price feed is found


```solidity
error ChainlinkOracle_NoPriceFeed();
```

### ChainlinkOracle_ZeroPrice
Error thrown when price is zero


```solidity
error ChainlinkOracle_ZeroPrice();
```

