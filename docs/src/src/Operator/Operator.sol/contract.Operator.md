# Operator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/00d040411754d9ec62fde1c26b93be292ca3e328/src\Operator\Operator.sol)

**Inherits:**
[IOperatorAccess](/src\interfaces\IOperator.sol\interface.IOperatorAccess.md), [IOperator](/src\interfaces\IOperator.sol\interface.IOperator.md), [ExponentialNoError](/src\math\ExponentialNoError.sol\abstract.ExponentialNoError.md)


## State Variables
### CLOSE_FACTOR_MIN_MANTISSA

```solidity
uint256 internal constant CLOSE_FACTOR_MIN_MANTISSA = 0.05e18;
```


### CLOSE_FACTOR_MAX_MANTISSA

```solidity
uint256 internal constant CLOSE_FACTOR_MAX_MANTISSA = 0.9e18;
```


### COLLATERAL_FACTOR_MAX_MANTISSA

```solidity
uint256 internal constant COLLATERAL_FACTOR_MAX_MANTISSA = 0.9e18;
```


### admin
Administrator for this contract


```solidity
address public override admin;
```


### pendingAdmin
Pending administrator for this contract


```solidity
address public override pendingAdmin;
```


### rolesOpeartor
Roles manager


```solidity
IRoles public override rolesOpeartor;
```


### oracleOperator
Oracle which gives the price of any given asset


```solidity
address public override oracleOperator;
```


### closeFactorMantissa
Multiplier used to calculate the maximum repayAmount when liquidating a borrow


```solidity
uint256 public override closeFactorMantissa;
```


### liquidationIncentiveMantissa
Multiplier representing the discount on collateral that a liquidator receives


```solidity
uint256 public override liquidationIncentiveMantissa;
```


### accountAssets
Per-account mapping of "assets you are in", capped by maxAssets


```solidity
mapping(address => address[]) public accountAssets;
```


### markets
Official mapping of mTokens -> Market metadata

*Used e.g. to determine if a market is supported*


```solidity
mapping(address => IOperatorData.Market) public markets;
```


### allMarkets
A list of all markets


```solidity
address[] public allMarkets;
```


### borrowCaps
Borrow caps enforced by borrowAllowed for each mToken address. Defaults to zero which corresponds to unlimited borrowing.


```solidity
mapping(address => uint256) public override borrowCaps;
```


### supplyCaps
Supply caps enforced by supplyAllowed for each mToken address. Defaults to zero which corresponds to unlimited supplying.


```solidity
mapping(address => uint256) public override supplyCaps;
```


### rewardDistributor
Reward Distributor to markets supply and borrow (including protocol token)


```solidity
address public override rewardDistributor;
```


## Functions
### onlyAdmin


```solidity
modifier onlyAdmin();
```

### constructor


```solidity
constructor();
```

### setPriceOracle

Sets a new price oracle

*Admin function to set a new price oracle*


```solidity
function setPriceOracle(address newOracle) external onlyAdmin;
```

### setCloseFactor

Sets the closeFactor used when liquidating borrows

*Admin function to set closeFactor*


```solidity
function setCloseFactor(uint256 newCloseFactorMantissa) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCloseFactorMantissa`|`uint256`|New close factor, scaled by 1e18|


### getAssetsIn

Returns the assets an account has entered


```solidity
function getAssetsIn(address _user) external view override returns (address[] memory mTokens);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|The address of the account to pull assets for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|A dynamic list with the assets the account has entered|


### checkMembership

Returns whether the given account is entered in the given asset


```solidity
function checkMembership(address account, address mToken) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the account to check|
|`mToken`|`address`|The mToken to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the account is in the asset, otherwise false.|


### getAllMarkets

A list of all markets


```solidity
function getAllMarkets() external view returns (address[] memory mTokens);
```

### getAccountLiquidity

Determine the current account liquidity wrt collateral requirements


```solidity
function getAccountLiquidity(address account) public view returns (uint256, uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|account liquidity in excess of collateral requirements, account shortfall below collateral requirements)|
|`<none>`|`uint256`||


### getHypotheticalAccountLiquidity

Determine what the account liquidity would be if the given amounts were redeemed/borrowed


```solidity
function getHypotheticalAccountLiquidity(
    address account,
    address mTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount
) external view returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to determine liquidity for|
|`mTokenModify`|`address`|The market to hypothetically redeem/borrow in|
|`redeemTokens`|`uint256`|The number of tokens to hypothetically redeem|
|`borrowAmount`|`uint256`|The amount of underlying to hypothetically borrow|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|hypothetical account liquidity in excess of collateral requirements, hypothetical account shortfall below collateral requirements)|
|`<none>`|`uint256`||


### liquidateCalculateSeizeTokens

Calculate number of tokens of collateral asset to seize given an underlying amount

*Used in liquidation (called in mTokenBorrowed.liquidate)*


```solidity
function liquidateCalculateSeizeTokens(address mTokenBorrowed, address mTokenCollateral, uint256 actualRepayAmount)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenBorrowed`|`address`|The address of the borrowed cToken|
|`mTokenCollateral`|`address`|The address of the collateral cToken|
|`actualRepayAmount`|`uint256`|The amount of mTokenBorrowed underlying to convert into mTokenCollateral tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|number of mTokenCollateral tokens to be seized in a liquidation|


### activate

Add assets to be included in account liquidity calculation


```solidity
function activate(address[] calldata _mTokens) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mTokens`|`address[]`|The list of addresses of the mToken markets to be enabled|


### deactivate

Removes asset from sender's account liquidity calculation

*Sender must not have an outstanding borrow balance in the asset,
or be providing necessary collateral for an outstanding borrow.*


```solidity
function deactivate(address _mToken) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|The address of the asset to be removed|


### _activateMarket


```solidity
function _activateMarket(address _mToken, address borrower) private;
```

### _redeemCheck


```solidity
function _redeemCheck(
    address mToken,
    address redeemer,
    uint256 redeemTokens,
    uint256 amountOwed,
    uint256 exchangeRateMantissa
) private view;
```

### _getHypotheticalAccountLiquidity


```solidity
function _getHypotheticalAccountLiquidity(
    address account,
    address mTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount,
    uint256 tokensHeld,
    uint256 amountOwed,
    uint256 exchangeRateMantissa
) private view returns (uint256, uint256);
```

## Events
### MarketEntered
Emitted when an account enters a market


```solidity
event MarketEntered(address indexed mToken, address indexed account);
```

### MarketExited
Emitted when an account exits a market


```solidity
event MarketExited(address indexed mToken, address indexed account);
```

### NewCloseFactor
Emitted Emitted when close factor is changed by admin


```solidity
event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);
```

### NewCollateralFactor
Emitted when a collateral factor is changed by admin


```solidity
event NewCollateralFactor(
    address indexed mToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa
);
```

### NewLiquidationIncentive
Emitted when liquidation incentive is changed by admin


```solidity
event NewLiquidationIncentive(uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa);
```

### NewPriceOracle
Emitted when price oracle is changed


```solidity
event NewPriceOracle(address indexed oldPriceOracle, address indexed newPriceOracle);
```

## Errors
### Operator_MarketNotListed

```solidity
error Operator_MarketNotListed();
```

### Operator_MarketAlreadyListed

```solidity
error Operator_MarketAlreadyListed();
```

### Operator_Deactivate_SnapshotFetchingFailed

```solidity
error Operator_Deactivate_SnapshotFetchingFailed();
```

### Operator_Deactivate_MarketBalanceOwed

```solidity
error Operator_Deactivate_MarketBalanceOwed();
```

### Operator_OracleUnderlyingFetchError

```solidity
error Operator_OracleUnderlyingFetchError();
```

### Operator_InsufficientLiquidity

```solidity
error Operator_InsufficientLiquidity();
```

### Operator_AssetNotFound

```solidity
error Operator_AssetNotFound();
```

### Operator_PriceFetchFailed

```solidity
error Operator_PriceFetchFailed();
```

### Operator_OnlyAdmin

```solidity
error Operator_OnlyAdmin();
```

### Operator_OnlyAdminOrRole

```solidity
error Operator_OnlyAdminOrRole();
```

### Operator_InvalidCollateralFactor

```solidity
error Operator_InvalidCollateralFactor();
```

### Operator_EmptyPrice

```solidity
error Operator_EmptyPrice();
```

### Operator_WrongMarket

```solidity
error Operator_WrongMarket();
```

## Structs
### AccountLiquidityLocalVars
*Local vars for avoiding stack-depth limits in calculating account liquidity.
Note that `mTokenBalance` is the number of mTokens the account owns in the market,
whereas `borrowBalance` is the amount of underlying that the account has borrowed.*


```solidity
struct AccountLiquidityLocalVars {
    uint256 sumCollateral;
    uint256 sumBorrowPlusEffects;
    uint256 mTokenBalance;
    uint256 borrowBalance;
    uint256 exchangeRateMantissa;
    uint256 oraclePriceMantissa;
    Exp collateralFactor;
    Exp exchangeRate;
    Exp oraclePrice;
    Exp tokensToDenom;
}
```

