# mTokenStorage
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/mToken/mTokenStorage.sol)

**Inherits:**
[ImToken](/src/interfaces/ImToken.sol/interface.ImToken.md), [ExponentialNoError](/src/utils/ExponentialNoError.sol/abstract.ExponentialNoError.md)

**Title:**
mTokenStorage

**Author:**
Merge Layers Inc.

Storage contract for mToken


## State Variables
### RESERVE_FACTOR_MAX_MANTISSA
Maximum fraction of interest that can be set aside for reserves


```solidity
uint256 internal constant RESERVE_FACTOR_MAX_MANTISSA = 1e18
```


### PROTOCOL_SEIZE_SHARE_MANTISSA
Share of seized collateral that is added to reserves


```solidity
uint256 internal constant PROTOCOL_SEIZE_SHARE_MANTISSA = 2.8e16
```


### admin
Administrator for this contract


```solidity
address payable public admin
```


### pendingAdmin
Pending administrator for this contract


```solidity
address payable public pendingAdmin
```


### operator
Contract which oversees inter-mToken operations


```solidity
address public operator
```


### rolesOperator
Roles manager


```solidity
IRoles public rolesOperator
```


### name
EIP-20 token name for this token


```solidity
string public name
```


### symbol
EIP-20 token symbol for this token


```solidity
string public symbol
```


### decimals
EIP-20 token decimals for this token


```solidity
uint8 public decimals
```


### interestRateModel
Model which tells what the current interest rate should be


```solidity
address public interestRateModel
```


### reserveFactorMantissa
Fraction of interest currently set aside for reserves


```solidity
uint256 public reserveFactorMantissa
```


### accrualBlockTimestamp
Block timestamp that interest was last accrued at


```solidity
uint256 public accrualBlockTimestamp
```


### borrowIndex
Accumulator of the total earned interest rate since the opening of the market


```solidity
uint256 public borrowIndex
```


### totalBorrows
Total amount of outstanding borrows of the underlying in this market


```solidity
uint256 public totalBorrows
```


### totalReserves
Total amount of reserves of the underlying held in this market


```solidity
uint256 public totalReserves
```


### totalSupply
Returns the value of tokens in existence.


```solidity
uint256 public totalSupply
```


### totalUnderlying
Returns the amount of underlying tokens


```solidity
uint256 public totalUnderlying
```


### borrowRateMaxMantissa
Maximum borrow rate that can ever be applied


```solidity
uint256 public borrowRateMaxMantissa = 0.0005e16
```


### accountBorrows
Mapping of account addresses to borrow snapshots


```solidity
mapping(address account => BorrowSnapshot snapshot) internal accountBorrows
```


### accountTokens
Mapping of account addresses to token balances


```solidity
mapping(address account => uint256 tokens) internal accountTokens
```


### transferAllowances
Mapping of owner to spender to allowance amount


```solidity
mapping(address owner => mapping(address spender => uint256 amount)) internal transferAllowances
```


### initialExchangeRateMantissa
Initial exchange rate used when minting the first mTokens (used when totalSupply = 0)


```solidity
uint256 internal initialExchangeRateMantissa
```


### __gap

```solidity
uint256[50] private __gap
```


## Functions
### accrueInterest

Accrues interest on the contract's outstanding loans


```solidity
function accrueInterest() external virtual;
```

### _accrueInterest

Accrues interest up to the current timestamp


```solidity
function _accrueInterest() internal;
```

### _doTransferIn

Performs a transfer in, reverting upon failure


```solidity
function _doTransferIn(address from, uint256 amount) internal virtual returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Sender address|
|`amount`|`uint256`|Amount to transfer in|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Amount actually transferred to the protocol|


### _doTransferOut

Performs a transfer out to recipient


```solidity
function _doTransferOut(address payable to, uint256 amount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


### _exchangeRateStored

Calculates the exchange rate from the underlying to the MToken

This function does not accrue interest before calculating the exchange rate
Can generate issues if inflated by an attacker when market is created
Solution: use 0 collateral factor initially


```solidity
function _exchangeRateStored() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|calculated exchange rate scaled by 1e18|


### _getBlockTimestamp

Retrieves current block timestamp (virtual for tests)


```solidity
function _getBlockTimestamp() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current block timestamp|


### _getCashPrior

Gets balance of this contract in terms of the underlying

This excludes the value of the current message, if any


```solidity
function _getCashPrior() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The quantity of underlying owned by this contract|


## Events
### NewRolesOperator
Event emitted when rolesOperator is changed


```solidity
event NewRolesOperator(address indexed oldRoles, address indexed newRoles);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldRoles`|`address`|Previous roles contract|
|`newRoles`|`address`|New roles contract|

### NewOperator
Event emitted when Operator is changed


```solidity
event NewOperator(address indexed oldOperator, address indexed newOperator);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldOperator`|`address`|Previous operator address|
|`newOperator`|`address`|New operator address|

### Transfer
EIP20 Transfer event


```solidity
event Transfer(address indexed from, address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Sender address|
|`to`|`address`|Receiver address|
|`amount`|`uint256`|Amount transferred|

### Approval
EIP20 Approval event


```solidity
event Approval(address indexed owner, address indexed spender, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|Token owner|
|`spender`|`address`|Spender address|
|`amount`|`uint256`|Allowed amount|

### AccrueInterest
Event emitted when interest is accrued


```solidity
event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cashPrior`|`uint256`|Cash prior to accrual|
|`interestAccumulated`|`uint256`|Interest accumulated during accrual|
|`borrowIndex`|`uint256`|New borrow index|
|`totalBorrows`|`uint256`|Total borrows after accrual|

### Mint
Event emitted when tokens are minted


```solidity
event Mint(address indexed minter, address indexed receiver, uint256 mintAmount, uint256 mintTokens);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|Address initiating mint|
|`receiver`|`address`|Receiver of minted tokens|
|`mintAmount`|`uint256`|Amount of underlying supplied|
|`mintTokens`|`uint256`|Amount of mTokens minted|

### Redeem
Event emitted when tokens are redeemed


```solidity
event Redeem(address indexed redeemer, uint256 redeemAmount, uint256 redeemTokens);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemer`|`address`|Address redeeming tokens|
|`redeemAmount`|`uint256`|Amount of underlying redeemed|
|`redeemTokens`|`uint256`|Number of tokens redeemed|

### Borrow
Event emitted when underlying is borrowed


```solidity
event Borrow(address indexed borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address`|Borrower address|
|`borrowAmount`|`uint256`|Amount borrowed|
|`accountBorrows`|`uint256`|Account borrow balance|
|`totalBorrows`|`uint256`|Total borrows after action|

### RepayBorrow
Event emitted when a borrow is repaid


```solidity
event RepayBorrow(
    address indexed payer,
    address indexed borrower,
    uint256 repayAmount,
    uint256 accountBorrows,
    uint256 totalBorrows
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`payer`|`address`|Address paying back|
|`borrower`|`address`|Borrower whose debt is reduced|
|`repayAmount`|`uint256`|Amount repaid|
|`accountBorrows`|`uint256`|Borrower's balance after repay|
|`totalBorrows`|`uint256`|Total borrows after repay|

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

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidator`|`address`|Liquidator address|
|`borrower`|`address`|Borrower being liquidated|
|`repayAmount`|`uint256`|Amount repaid|
|`mTokenCollateral`|`address`|Collateral market|
|`seizeTokens`|`uint256`|Tokens seized|

### NewMarketInterestRateModel
Event emitted when interestRateModel is changed


```solidity
event NewMarketInterestRateModel(address indexed oldInterestRateModel, address indexed newInterestRateModel);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldInterestRateModel`|`address`|Previous interest rate model|
|`newInterestRateModel`|`address`|New interest rate model|

### NewReserveFactor
Event emitted when the reserve factor is changed


```solidity
event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldReserveFactorMantissa`|`uint256`|Previous reserve factor|
|`newReserveFactorMantissa`|`uint256`|New reserve factor|

### ReservesAdded
Event emitted when the reserves are added


```solidity
event ReservesAdded(address indexed benefactor, uint256 addAmount, uint256 newTotalReserves);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`benefactor`|`address`|Address adding reserves|
|`addAmount`|`uint256`|Amount added|
|`newTotalReserves`|`uint256`|Total reserves after addition|

### ReservesReduced
Event emitted when the reserves are reduced


```solidity
event ReservesReduced(address indexed admin, uint256 reduceAmount, uint256 newTotalReserves);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address removing reserves|
|`reduceAmount`|`uint256`|Amount removed|
|`newTotalReserves`|`uint256`|Total reserves after reduction|

### NewBorrowRateMaxMantissa
Event emitted when the borrow max mantissa is updated


```solidity
event NewBorrowRateMaxMantissa(uint256 oldVal, uint256 maxMantissa);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldVal`|`uint256`|Previous max mantissa|
|`maxMantissa`|`uint256`|New max mantissa|

### SameChainFlowStateUpdated
Event emitted when same chain flow state is enabled or disabled


```solidity
event SameChainFlowStateUpdated(address indexed sender, bool _oldState, bool _newState);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Address updating the state|
|`_oldState`|`bool`|Previous state|
|`_newState`|`bool`|New state|

### ZkVerifierUpdated
Event emitted when zkVerifier is updated


```solidity
event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldVerifier`|`address`|Previous verifier|
|`newVerifier`|`address`|New verifier|

## Errors
### mt_OnlyAdmin
Thrown when caller is not admin


```solidity
error mt_OnlyAdmin();
```

### mt_RedeemEmpty
Thrown when redeem amounts are zero


```solidity
error mt_RedeemEmpty();
```

### mt_InvalidInput
Thrown when provided input is invalid


```solidity
error mt_InvalidInput();
```

### mt_OnlyAdminOrRole
Thrown when caller lacks required role


```solidity
error mt_OnlyAdminOrRole();
```

### mt_PriceFetchFailed
Thrown when price fetch fails


```solidity
error mt_PriceFetchFailed();
```

### mt_TransferNotValid
Thrown when transfer is not valid


```solidity
error mt_TransferNotValid();
```

### mt_MinAmountNotValid
Thrown when minimum amount is not met


```solidity
error mt_MinAmountNotValid();
```

### mt_BorrowRateTooHigh
Thrown when borrow rate exceeds maximum


```solidity
error mt_BorrowRateTooHigh();
```

### mt_AlreadyInitialized
Thrown when contract is already initialized


```solidity
error mt_AlreadyInitialized();
```

### mt_ReserveFactorTooHigh
Thrown when reserve factor exceeds limit


```solidity
error mt_ReserveFactorTooHigh();
```

### mt_ExchangeRateNotValid
Thrown when exchange rate is invalid


```solidity
error mt_ExchangeRateNotValid();
```

### mt_MarketMethodNotValid
Thrown when market method call is invalid


```solidity
error mt_MarketMethodNotValid();
```

### mt_LiquidateSeizeTooMuch
Thrown when liquidation seizes too much collateral


```solidity
error mt_LiquidateSeizeTooMuch();
```

### mt_RedeemCashNotAvailable
Thrown when redeem cash is unavailable


```solidity
error mt_RedeemCashNotAvailable();
```

### mt_BorrowCashNotAvailable
Thrown when borrow cash is unavailable


```solidity
error mt_BorrowCashNotAvailable();
```

### mt_ReserveCashNotAvailable
Thrown when reserve cash is unavailable


```solidity
error mt_ReserveCashNotAvailable();
```

### mt_RedeemTransferOutNotPossible
Thrown when redeem transfer out is not possible


```solidity
error mt_RedeemTransferOutNotPossible();
```

### mt_SameChainOperationsAreDisabled
Thrown when same chain operations are disabled


```solidity
error mt_SameChainOperationsAreDisabled();
```

### mt_CollateralBlockTimestampNotValid
Thrown when collateral block timestamp is invalid


```solidity
error mt_CollateralBlockTimestampNotValid();
```

### mTokenConfiguration_AddressNotValid
Thrown when configuration address is invalid


```solidity
error mTokenConfiguration_AddressNotValid();
```

## Structs
### BorrowSnapshot
Container for borrow balance information


```solidity
struct BorrowSnapshot {
    /// @notice Total balance (with accrued interest), after applying the most recent balance-changing action
    uint256 principal;
    /// @notice Global borrowIndex as of the most recent balance-changing action
    uint256 interestIndex;
}
```

