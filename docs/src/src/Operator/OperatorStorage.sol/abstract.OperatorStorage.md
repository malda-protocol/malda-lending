# OperatorStorage
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/3408a5de0b7e9a81798e0551731f955e891c66df/src\Operator\OperatorStorage.sol)

**Inherits:**
[IOperator](/src\interfaces\IOperator.sol\interface.IOperator.md), [IOperatorDefender](/src\interfaces\IOperator.sol\interface.IOperatorDefender.md), [ExponentialNoError](/src\utils\ExponentialNoError.sol\abstract.ExponentialNoError.md)


## State Variables
### admin
Administrator for this contract


```solidity
address public admin;
```


### pendingAdmin
Pending administrator for this contract


```solidity
address public pendingAdmin;
```


### rolesOperator
Roles manager


```solidity
IRoles public rolesOperator;
```


### oracleOperator
Oracle which gives the price of any given asset


```solidity
address public oracleOperator;
```


### closeFactorMantissa
Multiplier used to calculate the maximum repayAmount when liquidating a borrow


```solidity
uint256 public closeFactorMantissa;
```


### liquidationIncentiveMantissa
Multiplier representing the discount on collateral that a liquidator receives


```solidity
uint256 public liquidationIncentiveMantissa;
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
mapping(address => uint256) public borrowCaps;
```


### supplyCaps
Supply caps enforced by supplyAllowed for each mToken address. Defaults to zero which corresponds to unlimited supplying.


```solidity
mapping(address => uint256) public supplyCaps;
```


### rewardDistributor
Reward Distributor to markets supply and borrow (including protocol token)


```solidity
address public rewardDistributor;
```


### _paused

```solidity
mapping(address => mapping(ImTokenOperationTypes.OperationType => bool)) internal _paused;
```


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


## Functions
### onlyAdmin


```solidity
modifier onlyAdmin();
```

## Events
### ActionPaused
Emitted when pause status is changed


```solidity
event ActionPaused(address indexed mToken, ImTokenOperationTypes.OperationType _type, bool state);
```

### NewRewardDistributor
Emitted when reward distributor is changed


```solidity
event NewRewardDistributor(address indexed oldRewardDistributor, address indexed newRewardDistributor);
```

### NewBorrowCap
Emitted when borrow cap for a mToken is changed


```solidity
event NewBorrowCap(address indexed mToken, uint256 newBorrowCap);
```

### NewSupplyCap
Emitted when supply cap for a mToken is changed


```solidity
event NewSupplyCap(address indexed mToken, uint256 newBorrowCap);
```

### MarketListed
Emitted when an admin supports a market


```solidity
event MarketListed(address mToken);
```

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

### NewPendingAdmin
Emitted when pendingAdmin is changed


```solidity
event NewPendingAdmin(address indexed oldPendingAdmin, address indexed newPendingAdmin);
```

### NewAdmin
Emitted when pendingAdmin is accepted, which means admin is updated


```solidity
event NewAdmin(address indexed oldAdmin, address indexed newAdmin);
```

### NewRolesOperator
Event emitted when rolesOperator is changed


```solidity
event NewRolesOperator(address indexed oldRoles, address indexed newRoles);
```

## Errors
### Operator_Paused

```solidity
error Operator_Paused();
```

### Operator_Mismatch

```solidity
error Operator_Mismatch();
```

### Operator_OnlyAdmin

```solidity
error Operator_OnlyAdmin();
```

### Operator_EmptyPrice

```solidity
error Operator_EmptyPrice();
```

### Operator_WrongMarket

```solidity
error Operator_WrongMarket();
```

### Operator_InvalidInput

```solidity
error Operator_InvalidInput();
```

### Operator_AssetNotFound

```solidity
error Operator_AssetNotFound();
```

### Operator_RepayingTooMuch

```solidity
error Operator_RepayingTooMuch();
```

### Operator_OnlyAdminOrRole

```solidity
error Operator_OnlyAdminOrRole();
```

### Operator_MarketNotListed

```solidity
error Operator_MarketNotListed();
```

### Operator_PriceFetchFailed

```solidity
error Operator_PriceFetchFailed();
```

### Operator_SenderMustBeToken

```solidity
error Operator_SenderMustBeToken();
```

### Operator_MarketSupplyReached

```solidity
error Operator_MarketSupplyReached();
```

### Operator_RepayAmountNotValid

```solidity
error Operator_RepayAmountNotValid();
```

### Operator_MarketAlreadyListed

```solidity
error Operator_MarketAlreadyListed();
```

### Operator_InvalidRolesOperator

```solidity
error Operator_InvalidRolesOperator();
```

### Operator_InsufficientLiquidity

```solidity
error Operator_InsufficientLiquidity();
```

### Operator_MarketBorrowCapReached

```solidity
error Operator_MarketBorrowCapReached();
```

### Operator_InvalidCollateralFactor

```solidity
error Operator_InvalidCollateralFactor();
```

### Operator_InvalidRewardDistributor

```solidity
error Operator_InvalidRewardDistributor();
```

### Operator_OracleUnderlyingFetchError

```solidity
error Operator_OracleUnderlyingFetchError();
```

### Operator_Deactivate_MarketBalanceOwed

```solidity
error Operator_Deactivate_MarketBalanceOwed();
```

### Operator_Deactivate_SnapshotFetchingFailed

```solidity
error Operator_Deactivate_SnapshotFetchingFailed();
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

