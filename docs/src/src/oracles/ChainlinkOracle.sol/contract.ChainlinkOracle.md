# ChainlinkOracle
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\oracles\ChainlinkOracle.sol)

**Inherits:**
[IOracleOperator](/src\interfaces\IOracleOperator.sol\interface.IOracleOperator.md)


## State Variables
### priceFeeds

```solidity
mapping(string => IAggregatorV3) public priceFeeds;
```


### baseUnits

```solidity
mapping(string => uint256) public baseUnits;
```


### DECIMALS

```solidity
uint8 public constant DECIMALS = 18;
```


## Functions
### constructor


```solidity
constructor(string[] memory symbols_, IAggregatorV3[] memory feeds_, uint256[] memory baseUnits_);
```

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
|`<none>`|`uint256`|The underlying asset price mantissa (scaled by 1e18). Zero means the price is unavailable.|


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
|`<none>`|`uint256`|The underlying asset price mantissa (scaled by 1e18). Zero means the price is unavailable.|


### _getLatestPrice


```solidity
function _getLatestPrice(string memory symbol) internal view returns (uint256, uint256);
```

## Errors
### ChainlinkOracle_NoPriceFeed

```solidity
error ChainlinkOracle_NoPriceFeed();
```

### ChainlinkOracle_ZeroPrice

```solidity
error ChainlinkOracle_ZeroPrice();
```

