# ImToken
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/ImToken.sol)

**Inherits:**
[ImTokenMinimal](/src/interfaces/ImToken.sol/interface.ImTokenMinimal.md)

**Title:**
ImToken

**Author:**
Merge Layers Inc.

Core mToken interface with state views and actions


## Functions
### transfer

Transfers `amount` tokens to the `dst` address


```solidity
function transfer(address dst, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dst`|`address`|The address of the recipient|
|`amount`|`uint256`|The number of tokens to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success Whether the transfer was successful or not|


### transferFrom

Transfers `amount` tokens from the `src` address to the `dst` address


```solidity
function transferFrom(address src, address dst, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`src`|`address`|The address from which tokens are transferred|
|`dst`|`address`|The address to which tokens are transferred|
|`amount`|`uint256`|The number of tokens to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success Whether the transfer was successful or not|


### approve

Approves `spender` to spend `amount` tokens on behalf of the caller


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|The address authorized to spend tokens|
|`amount`|`uint256`|The number of tokens to approve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|success Whether the approval was successful or not|


### balanceOfUnderlying

Returns the underlying asset balance of the `owner`


```solidity
function balanceOfUnderlying(address owner) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address to query the balance of underlying assets for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|balance The balance of underlying assets owned by `owner`|


### totalBorrowsCurrent

Returns the total amount of borrows, accounting for interest


```solidity
function totalBorrowsCurrent() external returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|totalBorrowsCurrentAmount The total amount of borrows|


### borrowBalanceCurrent

Returns the current borrow balance for `account`, accounting for interest


```solidity
function borrowBalanceCurrent(address account) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to query the borrow balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|borrowBalance Current borrow balance|


### exchangeRateCurrent

Returns the current exchange rate, with interest accrued


```solidity
function exchangeRateCurrent() external returns (uint256 exchangeRate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`exchangeRate`|`uint256`|The current exchange rate|


### accrueInterest

Accrues interest on the contract's outstanding loans


```solidity
function accrueInterest() external;
```

### seize

Transfers collateral tokens (this market) to the liquidator.

Will fail unless called by another mToken during the process of liquidation.
Its absolutely critical to use msg.sender as the borrowed mToken and not a parameter.


```solidity
function seize(address liquidator, address borrower, uint256 seizeTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidator`|`address`|The account receiving seized collateral|
|`borrower`|`address`|The account having collateral seized|
|`seizeTokens`|`uint256`|The number of mTokens to seize|


### reduceReserves

Accrues interest and reduces reserves by transferring to admin


```solidity
function reduceReserves(uint256 reduceAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reduceAmount`|`uint256`|Amount of reduction to reserves|


### rolesOperator

Roles manager


```solidity
function rolesOperator() external view returns (IRoles);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IRoles`|roles Roles contract|


### admin

Administrator for this contract


```solidity
function admin() external view returns (address payable adminAddr);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`adminAddr`|`address payable`|Admin address|


### pendingAdmin

Pending administrator for this contract


```solidity
function pendingAdmin() external view returns (address payable pending);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pending`|`address payable`|Pending admin address|


### operator

Contract which oversees inter-mToken operations


```solidity
function operator() external view returns (address operatorAddr);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`operatorAddr`|`address`|Operator address|


### interestRateModel

Model which tells what the current interest rate should be


```solidity
function interestRateModel() external view returns (address interestModel);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`interestModel`|`address`|Interest rate model address|


### reserveFactorMantissa

Fraction of interest currently set aside for reserves


```solidity
function reserveFactorMantissa() external view returns (uint256 reserveFactor);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reserveFactor`|`uint256`|Current reserve factor mantissa|


### accrualBlockTimestamp

Block timestamp that interest was last accrued at


```solidity
function accrualBlockTimestamp() external view returns (uint256 timestamp);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Last accrual block timestamp|


### borrowIndex

Accumulator of the total earned interest rate since the opening of the market


```solidity
function borrowIndex() external view returns (uint256 index);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|Borrow index|


### totalBorrows

Total amount of outstanding borrows of the underlying in this market


```solidity
function totalBorrows() external view returns (uint256 borrows);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`borrows`|`uint256`|Total borrows|


### totalReserves

Total amount of reserves of the underlying held in this market


```solidity
function totalReserves() external view returns (uint256 reserves);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reserves`|`uint256`|Total reserves|


### getAccountSnapshot

Returns the snapshot of account details for the given `account`


```solidity
function getAccountSnapshot(address account)
    external
    view
    returns (uint256 tokenBalance, uint256 borrowBalance, uint256 exchangeRate);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to query the account snapshot for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenBalance`|`uint256`|Token balance|
|`borrowBalance`|`uint256`|Borrow balance|
|`exchangeRate`|`uint256`|Exchange rate|


### borrowBalanceStored

Returns the stored borrow balance for `account`, without accruing interest


```solidity
function borrowBalanceStored(address account) external view returns (uint256 storedBalance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to query the stored borrow balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`storedBalance`|`uint256`|The stored borrow balance|


### exchangeRateStored

Returns the stored exchange rate, without accruing interest


```solidity
function exchangeRateStored() external view returns (uint256 exchangeRateStoredMantissa);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`exchangeRateStoredMantissa`|`uint256`|The stored exchange rate|


### getCash

Returns the total amount of available cash in the contract


```solidity
function getCash() external view returns (uint256 cash);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`cash`|`uint256`|The total amount of cash|


### allowance

Returns the current allowance the `spender` has from the `owner`


```solidity
function allowance(address owner, address spender) external view returns (uint256 allowanceAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the token holder|
|`spender`|`address`|The address authorized to spend the tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`allowanceAmount`|`uint256`|The current remaining number of tokens `spender` can spend|


### balanceOf

Returns the balance of tokens held by `owner`


```solidity
function balanceOf(address owner) external view returns (uint256 ownerBalance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address to query the balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ownerBalance`|`uint256`|The balance of tokens owned by `owner`|


### borrowRatePerBlock

Returns the current borrow rate per block


```solidity
function borrowRatePerBlock() external view returns (uint256 borrowRate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`borrowRate`|`uint256`|The current borrow rate per block, scaled by 1e18|


### supplyRatePerBlock

Returns the current supply rate per block


```solidity
function supplyRatePerBlock() external view returns (uint256 supplyRate);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`supplyRate`|`uint256`|The current supply rate per block, scaled by 1e18|


