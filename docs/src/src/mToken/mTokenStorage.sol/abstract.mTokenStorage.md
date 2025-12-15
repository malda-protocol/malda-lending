# mTokenStorage
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\mToken\mTokenStorage.sol)

**Inherits:**
[ImToken](/src\interfaces\ImToken.sol\interface.ImToken.md), [ExponentialNoError](/src\utils\ExponentialNoError.sol\abstract.ExponentialNoError.md)


## State Variables
### admin
Administrator for this contract


```solidity
address payable public admin;
```


### pendingAdmin
Pending administrator for this contract


```solidity
address payable public pendingAdmin;
```


### operator
Contract which oversees inter-mToken operations


```solidity
address public operator;
```


### rolesOperator
Roles manager


```solidity
IRoles public rolesOperator;
```


### name
EIP-20 token name for this token


```solidity
string public name;
```


### symbol
EIP-20 token symbol for this token


```solidity
string public symbol;
```


### decimals
EIP-20 token decimals for this token


```solidity
uint8 public decimals;
```


### interestRateModel
Model which tells what the current interest rate should be


```solidity
address public interestRateModel;
```


### reserveFactorMantissa
Fraction of interest currently set aside for reserves


```solidity
uint256 public reserveFactorMantissa;
```


### accrualBlockTimestamp
Block timestamp that interest was last accrued at


```solidity
uint256 public accrualBlockTimestamp;
```


### borrowIndex
Accumulator of the total earned interest rate since the opening of the market


```solidity
uint256 public borrowIndex;
```


### totalBorrows
Total amount of outstanding borrows of the underlying in this market


```solidity
uint256 public totalBorrows;
```


### totalReserves
Total amount of reserves of the underlying held in this market


```solidity
uint256 public totalReserves;
```


### totalSupply
Returns the value of tokens in existence.


```solidity
uint256 public totalSupply;
```


### totalUnderlying
Returns the amount of underlying tokens


```solidity
uint256 public totalUnderlying;
```


### borrowRateMaxMantissa
Maximum borrow rate that can ever be applied


```solidity
uint256 public borrowRateMaxMantissa = 0.0005e16;
```


### accountBorrows

```solidity
mapping(address => BorrowSnapshot) internal accountBorrows;
```


### accountTokens

```solidity
mapping(address => uint256) internal accountTokens;
```


### transferAllowances

```solidity
mapping(address => mapping(address => uint256)) internal transferAllowances;
```


### initialExchangeRateMantissa
Initial exchange rate used when minting the first mTokens (used when totalSupply = 0)


```solidity
uint256 internal initialExchangeRateMantissa;
```


### RESERVE_FACTOR_MAX_MANTISSA
Maximum fraction of interest that can be set aside for reserves


```solidity
uint256 internal constant RESERVE_FACTOR_MAX_MANTISSA = 1e18;
```


### PROTOCOL_SEIZE_SHARE_MANTISSA
Share of seized collateral that is added to reserves


```solidity
uint256 internal constant PROTOCOL_SEIZE_SHARE_MANTISSA = 2.8e16;
```


## Functions
### accrueInterest

Accrues interest on the contract's outstanding loans


```solidity
function accrueInterest() external virtual;
```

### _getBlockTimestamp

*Function to simply retrieve block timestamp
This exists mainly for inheriting test contracts to stub this result.*


```solidity
function _getBlockTimestamp() internal view virtual returns (uint256);
```

### _exchangeRateStored

Calculates the exchange rate from the underlying to the MToken

*This function does not accrue interest before calculating the exchange rate
Can generate issues if inflated by an attacker when market is created
Solution: use 0 collateral factor initially*


```solidity
function _exchangeRateStored() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|calculated exchange rate scaled by 1e18|


### _getCashPrior

Gets balance of this contract in terms of the underlying

*This excludes the value of the current message, if any*


```solidity
function _getCashPrior() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The quantity of underlying owned by this contract|


### _doTransferIn

*Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
This may revert due to insufficient balance or insufficient allowance.*


```solidity
function _doTransferIn(address from, uint256 amount) internal virtual returns (uint256);
```

### _doTransferOut

*Performs a transfer out, ideally returning an explanatory error code upon failure rather than reverting.
If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.*


```solidity
function _doTransferOut(address payable to, uint256 amount) internal virtual;
```

### _accrueInterest


```solidity
function _accrueInterest() internal;
```

## Events
### NewRolesOperator
Event emitted when rolesOperator is changed


```solidity
event NewRolesOperator(address indexed oldRoles, address indexed newRoles);
```

### NewOperator
Event emitted when Operator is changed


```solidity
event NewOperator(address indexed oldOperator, address indexed newOperator);
```

### Transfer
EIP20 Transfer event


```solidity
event Transfer(address indexed from, address indexed to, uint256 amount);
```

### Approval
EIP20 Approval event


```solidity
event Approval(address indexed owner, address indexed spender, uint256 amount);
```

### AccrueInterest
Event emitted when interest is accrued


```solidity
event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
```

### Mint
Event emitted when tokens are minted


```solidity
event Mint(address indexed minter, address indexed receiver, uint256 mintAmount, uint256 mintTokens);
```

### Redeem
Event emitted when tokens are redeemed


```solidity
event Redeem(address indexed redeemer, uint256 redeemAmount, uint256 redeemTokens);
```

### Borrow
Event emitted when underlying is borrowed


```solidity
event Borrow(address indexed borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
```

### RepayBorrow
Event emitted when a borrow is repaid


```solidity
event RepayBorrow(
    address indexed payer, address indexed borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows
);
```

### LiquidateBorrow
Event emitted when a borrow is liquidated


```solidity
event LiquidateBorrow(
    address indexed liquidator,
    address indexed borrower,
    uint256 repayAmount,
    address indexed mTokenCollateral,
    uint256 seizeTokens
);
```

### NewMarketInterestRateModel
Event emitted when interestRateModel is changed


```solidity
event NewMarketInterestRateModel(address indexed oldInterestRateModel, address indexed newInterestRateModel);
```

### NewReserveFactor
Event emitted when the reserve factor is changed


```solidity
event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
```

### ReservesAdded
Event emitted when the reserves are added


```solidity
event ReservesAdded(address indexed benefactor, uint256 addAmount, uint256 newTotalReserves);
```

### ReservesReduced
Event emitted when the reserves are reduced


```solidity
event ReservesReduced(address indexed admin, uint256 reduceAmount, uint256 newTotalReserves);
```

### NewBorrowRateMaxMantissa
Event emitted when the borrow max mantissa is updated


```solidity
event NewBorrowRateMaxMantissa(uint256 oldVal, uint256 maxMantissa);
```

### SameChainFlowStateUpdated
Event emitted when same chain flow state is enabled or disabled


```solidity
event SameChainFlowStateUpdated(address indexed sender, bool _oldState, bool _newState);
```

### ZkVerifierUpdated
Event emitted when same chain flow state is enabled or disabled


```solidity
event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
```

## Errors
### mt_OnlyAdmin

```solidity
error mt_OnlyAdmin();
```

### mt_RedeemEmpty

```solidity
error mt_RedeemEmpty();
```

### mt_InvalidInput

```solidity
error mt_InvalidInput();
```

### mt_OnlyAdminOrRole

```solidity
error mt_OnlyAdminOrRole();
```

### mt_TransferNotValid

```solidity
error mt_TransferNotValid();
```

### mt_MinAmountNotValid

```solidity
error mt_MinAmountNotValid();
```

### mt_BorrowRateTooHigh

```solidity
error mt_BorrowRateTooHigh();
```

### mt_AlreadyInitialized

```solidity
error mt_AlreadyInitialized();
```

### mt_ReserveFactorTooHigh

```solidity
error mt_ReserveFactorTooHigh();
```

### mt_ExchangeRateNotValid

```solidity
error mt_ExchangeRateNotValid();
```

### mt_MarketMethodNotValid

```solidity
error mt_MarketMethodNotValid();
```

### mt_LiquidateSeizeTooMuch

```solidity
error mt_LiquidateSeizeTooMuch();
```

### mt_RedeemCashNotAvailable

```solidity
error mt_RedeemCashNotAvailable();
```

### mt_BorrowCashNotAvailable

```solidity
error mt_BorrowCashNotAvailable();
```

### mt_ReserveCashNotAvailable

```solidity
error mt_ReserveCashNotAvailable();
```

### mt_RedeemTransferOutNotPossible

```solidity
error mt_RedeemTransferOutNotPossible();
```

### mt_SameChainOperationsAreDisabled

```solidity
error mt_SameChainOperationsAreDisabled();
```

### mt_CollateralBlockTimestampNotValid

```solidity
error mt_CollateralBlockTimestampNotValid();
```

## Structs
### BorrowSnapshot
Container for borrow balance information


```solidity
struct BorrowSnapshot {
    uint256 principal;
    uint256 interestIndex;
}
```

