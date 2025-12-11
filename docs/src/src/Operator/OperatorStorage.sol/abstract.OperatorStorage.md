# OperatorStorage
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/Operator/OperatorStorage.sol)

**Inherits:**
[IOperator](/src/interfaces/IOperator.sol/interface.IOperator.md), [IOperatorDefender](/src/interfaces/IOperator.sol/interface.IOperatorDefender.md), [ExponentialNoError](/src/utils/ExponentialNoError.sol/abstract.ExponentialNoError.md)

**Title:**
OperatorStorage

**Author:**
Merge Layers Inc.

Storage contract for Operator


## State Variables
### CLOSE_FACTOR_MIN_MANTISSA
closeFactorMantissa must be strictly greater than this value


```solidity
uint256 internal constant CLOSE_FACTOR_MIN_MANTISSA = 0.05e18
```


### CLOSE_FACTOR_MAX_MANTISSA
closeFactorMantissa must not exceed this value


```solidity
uint256 internal constant CLOSE_FACTOR_MAX_MANTISSA = 0.9e18
```


### COLLATERAL_FACTOR_MAX_MANTISSA
No collateralFactorMantissa may exceed this value


```solidity
uint256 internal constant COLLATERAL_FACTOR_MAX_MANTISSA = 0.9e18
```


### rolesOperator
Roles


```solidity
IRoles public rolesOperator
```


### blacklistOperator
Blacklist


```solidity
IBlacklister public blacklistOperator
```


### oracleOperator
Oracle which gives the price of any given asset


```solidity
address public oracleOperator
```


### closeFactorMantissa
Multiplier used to calculate the maximum repayAmount when liquidating a borrow


```solidity
uint256 public closeFactorMantissa
```


### liquidationIncentiveMantissa
Mapping of markets to liquidation incentive mantissa


```solidity
mapping(address market => uint256 incentive) public liquidationIncentiveMantissa
```


### accountAssets
Per-account mapping of "assets you are in", capped by maxAssets


```solidity
mapping(address account => address[] assets) public accountAssets
```


### markets
Mapping of mTokens to market data

Used e.g. to determine if a market is supported


```solidity
mapping(address mToken => IOperatorData.Market market) public markets
```


### allMarkets
A list of all markets


```solidity
address[] public allMarkets
```


### borrowCaps
Mapping of mTokens to borrow caps


```solidity
mapping(address mToken => uint256 cap) public borrowCaps
```


### supplyCaps
Mapping of mTokens to supply caps


```solidity
mapping(address mToken => uint256 cap) public supplyCaps
```


### minBorrowSize
Mapping of mTokens to minimum borrow size


```solidity
mapping(address mToken => uint256 size) public minBorrowSize
```


### limitPerTimePeriod
Should return outflow limit


```solidity
uint256 public limitPerTimePeriod
```


### cumulativeOutflowVolume
Should return outflow volume


```solidity
uint256 public cumulativeOutflowVolume
```


### lastOutflowResetTimestamp
Should return last reset time for outflow check


```solidity
uint256 public lastOutflowResetTimestamp
```


### outflowResetTimeWindow
Should return the outflow volume time window


```solidity
uint256 public outflowResetTimeWindow
```


### userWhitelisted
Mapping of users to whitelist status


```solidity
mapping(address user => bool whitelisted) public userWhitelisted
```


### whitelistEnabled
Whether whitelist is enabled


```solidity
bool public whitelistEnabled
```


### _paused
Mapping of mTokens to operation types to pause status


```solidity
mapping(address mToken => mapping(ImTokenOperationTypes.OperationType actionType => bool paused)) internal _paused
```


### __gap

```solidity
uint256[50] private __gap
```


## Events
### UserWhitelisted
Emitted when user whitelist status is changed


```solidity
event UserWhitelisted(address indexed user, bool state);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address of the user|
|`state`|`bool`|Whitelist state|

### WhitelistEnabled
Emitted when whitelist is enabled


```solidity
event WhitelistEnabled();
```

### WhitelistDisabled
Emitted when whitelist is disabled


```solidity
event WhitelistDisabled();
```

### ActionPaused
Emitted when pause status is changed


```solidity
event ActionPaused(address indexed mToken, ImTokenOperationTypes.OperationType _type, bool state);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|
|`_type`|`ImTokenOperationTypes.OperationType`|Operation type paused|
|`state`|`bool`|New pause state|

### NewBorrowCap
Emitted when borrow cap for a mToken is changed


```solidity
event NewBorrowCap(address indexed mToken, uint256 newBorrowCap);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|
|`newBorrowCap`|`uint256`|New borrow cap|

### NewSupplyCap
Emitted when supply cap for a mToken is changed


```solidity
event NewSupplyCap(address indexed mToken, uint256 newBorrowCap);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|
|`newBorrowCap`|`uint256`|New supply cap|

### MarketListed
Emitted when an admin supports a market


```solidity
event MarketListed(address mToken);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market listed|

### MarketEntered
Emitted when an account enters a market


```solidity
event MarketEntered(address indexed mToken, address indexed account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market entered|
|`account`|`address`|Account entering|

### MarketExited
Emitted when an account exits a market


```solidity
event MarketExited(address indexed mToken, address indexed account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market exited|
|`account`|`address`|Account exiting|

### NewCloseFactor
Emitted when close factor is changed by admin


```solidity
event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldCloseFactorMantissa`|`uint256`|Previous close factor|
|`newCloseFactorMantissa`|`uint256`|New close factor|

### NewCollateralFactor
Emitted when a collateral factor is changed by admin


```solidity
event NewCollateralFactor(
    address indexed mToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|
|`oldCollateralFactorMantissa`|`uint256`|Previous collateral factor|
|`newCollateralFactorMantissa`|`uint256`|New collateral factor|

### NewLiquidationIncentive
Emitted when liquidation incentive is changed by admin


```solidity
event NewLiquidationIncentive(
    address market, uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|Market address|
|`oldLiquidationIncentiveMantissa`|`uint256`|Previous incentive|
|`newLiquidationIncentiveMantissa`|`uint256`|New incentive|

### NewPriceOracle
Emitted when price oracle is changed


```solidity
event NewPriceOracle(address indexed oldPriceOracle, address indexed newPriceOracle);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldPriceOracle`|`address`|Previous price oracle|
|`newPriceOracle`|`address`|New price oracle|

### NewRolesOperator
Event emitted when rolesOperator is changed


```solidity
event NewRolesOperator(address indexed oldRoles, address indexed newRoles);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldRoles`|`address`|Previous roles operator|
|`newRoles`|`address`|New roles operator|

### OutflowLimitUpdated
Event emitted when outflow limit is updated


```solidity
event OutflowLimitUpdated(address indexed sender, uint256 oldLimit, uint256 newLimit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Caller updating limit|
|`oldLimit`|`uint256`|Previous limit|
|`newLimit`|`uint256`|New limit|

### OutflowTimeWindowUpdated
Event emitted when outflow reset time window is updated


```solidity
event OutflowTimeWindowUpdated(uint256 oldWindow, uint256 newWindow);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldWindow`|`uint256`|Previous window|
|`newWindow`|`uint256`|New window|

### OutflowVolumeReset
Event emitted when outflow volume has been reset


```solidity
event OutflowVolumeReset();
```

### MinBorrowSizeSet
Event emitted when min borrow size set for markets


```solidity
event MinBorrowSizeSet(address[] markets, uint256[] amounts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`markets`|`address[]`|Markets being updated|
|`amounts`|`uint256[]`|Borrow size amounts|

## Errors
### Operator_Paused
Error when action is paused


```solidity
error Operator_Paused();
```

### Operator_Mismatch
Error when data mismatch occurs


```solidity
error Operator_Mismatch();
```

### Operator_OnlyAdmin
Error when caller is not admin


```solidity
error Operator_OnlyAdmin();
```

### Operator_EmptyPrice
Error when oracle price is empty


```solidity
error Operator_EmptyPrice();
```

### Operator_WrongMarket
Error when wrong market is referenced


```solidity
error Operator_WrongMarket();
```

### Operator_InvalidInput
Error when input is invalid


```solidity
error Operator_InvalidInput();
```

### Operator_AssetNotFound
Error when asset is not found


```solidity
error Operator_AssetNotFound();
```

### Operator_RepayingTooMuch
Error when repay amount exceeds allowed


```solidity
error Operator_RepayingTooMuch();
```

### Operator_OnlyAdminOrRole
Error when caller lacks admin or role permissions


```solidity
error Operator_OnlyAdminOrRole();
```

### Operator_MarketNotListed
Error when market is not listed


```solidity
error Operator_MarketNotListed();
```

### Operator_UserBlacklisted
Error when user is blacklisted


```solidity
error Operator_UserBlacklisted();
```

### Operator_PriceFetchFailed
Error when price fetch fails


```solidity
error Operator_PriceFetchFailed();
```

### Operator_SenderMustBeToken
Error when sender must be token


```solidity
error Operator_SenderMustBeToken();
```

### Operator_UserNotWhitelisted
Error when user is not whitelisted


```solidity
error Operator_UserNotWhitelisted();
```

### Operator_MarketSupplyReached
Error when market supply cap reached


```solidity
error Operator_MarketSupplyReached();
```

### Operator_RepayAmountNotValid
Error when repay amount invalid


```solidity
error Operator_RepayAmountNotValid();
```

### Operator_MarketAlreadyListed
Error when market already listed


```solidity
error Operator_MarketAlreadyListed();
```

### Operator_OutflowVolumeReached
Error when outflow volume reached


```solidity
error Operator_OutflowVolumeReached();
```

### Operator_InvalidRolesOperator
Error when roles operator invalid


```solidity
error Operator_InvalidRolesOperator();
```

### Operator_InsufficientLiquidity
Error when insufficient liquidity


```solidity
error Operator_InsufficientLiquidity();
```

### Operator_MarketBorrowSizeNotMet
Error when borrow size not met


```solidity
error Operator_MarketBorrowSizeNotMet();
```

### Operator_MarketBorrowCapReached
Error when borrow cap reached


```solidity
error Operator_MarketBorrowCapReached();
```

### Operator_InvalidCollateralFactor
Error when collateral factor invalid


```solidity
error Operator_InvalidCollateralFactor();
```

### Operator_InvalidBlacklistOperator
Error when blacklist operator invalid


```solidity
error Operator_InvalidBlacklistOperator();
```

### Operator_OracleUnderlyingFetchError
Error when oracle underlying fetch fails


```solidity
error Operator_OracleUnderlyingFetchError();
```

### Operator_Deactivate_MarketBalanceOwed
Error when market has balance owed during deactivation


```solidity
error Operator_Deactivate_MarketBalanceOwed();
```

## Structs
### AccountLiquidityLocalVars
Local vars for avoiding stack-depth limits in calculating account liquidity.


```solidity
struct AccountLiquidityLocalVars {
    uint256 sumCollateral;
    uint256 sumBorrowPlusEffects;
    /// @notice Number of mTokens the account owns in the market
    uint256 mTokenBalance;
    /// @notice Amount of underlying that the account has borrowed
    uint256 borrowBalance;
    uint256 exchangeRateMantissa;
    uint256 oraclePriceMantissa;
    uint256 collateralFactorMantissa;
    uint256 liquidationIncentiveMantissa;
    uint256 borrowLimitMantissa;
    Exp collateralFactor;
    Exp exchangeRate;
    Exp oraclePrice;
    Exp tokensToDenom;
}
```

