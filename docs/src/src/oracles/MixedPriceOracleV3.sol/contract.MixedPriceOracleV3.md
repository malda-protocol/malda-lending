# MixedPriceOracleV3
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\oracles\MixedPriceOracleV3.sol)

**Inherits:**
[IOracleOperator](/src\interfaces\IOracleOperator.sol\interface.IOracleOperator.md)


## State Variables
### STALENESS_PERIOD

```solidity
uint256 public immutable STALENESS_PERIOD;
```


### configs

```solidity
mapping(string => IDefaultAdapter.PriceConfig) public configs;
```


### stalenessPerSymbol

```solidity
mapping(string => uint256) public stalenessPerSymbol;
```


### roles

```solidity
IRoles public immutable roles;
```


## Functions
### constructor


```solidity
constructor(
    string[] memory symbols_,
    IDefaultAdapter.PriceConfig[] memory configs_,
    address roles_,
    uint256 stalenessPeriod_
);
```

### setStaleness


```solidity
function setStaleness(string memory symbol, uint256 val) external;
```

### setConfig


```solidity
function setConfig(string memory symbol, IDefaultAdapter.PriceConfig memory config) external;
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
function _getLatestPrice(string memory symbol, IDefaultAdapter.PriceConfig memory config)
    internal
    view
    returns (uint256, uint256);
```

### _getStaleness


```solidity
function _getStaleness(string memory symbol) internal view returns (uint256);
```

## Events
### ConfigSet

```solidity
event ConfigSet(string symbol, IDefaultAdapter.PriceConfig config);
```

### StalenessUpdated

```solidity
event StalenessUpdated(string symbol, uint256 val);
```

## Errors
### MixedPriceOracle_Unauthorized

```solidity
error MixedPriceOracle_Unauthorized();
```

### MixedPriceOracle_StalePrice

```solidity
error MixedPriceOracle_StalePrice();
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

