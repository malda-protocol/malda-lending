# mToken
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\mToken\mToken.sol)

**Inherits:**
[mTokenConfiguration](/src\mToken\mTokenConfiguration.sol\abstract.mTokenConfiguration.md), ReentrancyGuard


## Functions
### constructor


```solidity
constructor();
```

### _initializeMToken

Initialize the money market


```solidity
function _initializeMToken(
    address operator_,
    address interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator_`|`address`|The address of the Operator|
|`interestRateModel_`|`address`|The address of the interest rate model|
|`initialExchangeRateMantissa_`|`uint256`|The initial exchange rate, scaled by 1e18|
|`name_`|`string`|EIP-20 name of this token|
|`symbol_`|`string`|EIP-20 symbol of this token|
|`decimals_`|`uint8`|EIP-20 decimal precision of this token|


### allowance

Returns the current allowance the `spender` has from the `owner`


```solidity
function allowance(address owner, address spender) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address of the token holder|
|`spender`|`address`|The address authorized to spend the tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current remaining number of tokens `spender` can spend|


### balanceOf

Returns the value of tokens owned by `account`.


```solidity
function balanceOf(address owner) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`||


### balanceOfUnderlying

Returns the underlying asset balance of the `owner`


```solidity
function balanceOfUnderlying(address owner) external override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address to query the balance of underlying assets for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The balance of underlying assets owned by `owner`|


### getAccountSnapshot

Returns the snapshot of account details for the given `account`


```solidity
function getAccountSnapshot(address account) external view override returns (uint256, uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to query the account snapshot for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|(token balance, borrow balance, exchange rate)|
|`<none>`|`uint256`||
|`<none>`|`uint256`||


### borrowRatePerBlock

Returns the current borrow rate per block


```solidity
function borrowRatePerBlock() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current borrow rate per block, scaled by 1e18|


### supplyRatePerBlock

Returns the current supply rate per block


```solidity
function supplyRatePerBlock() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current supply rate per block, scaled by 1e18|


### borrowBalanceStored

Returns the stored borrow balance for `account`, without accruing interest


```solidity
function borrowBalanceStored(address account) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to query the stored borrow balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The stored borrow balance|


### getCash

Returns the total amount of available cash in the contract


```solidity
function getCash() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount of cash|


### exchangeRateStored

Returns the stored exchange rate, without accruing interest


```solidity
function exchangeRateStored() external view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The stored exchange rate|


### transfer

Transfers `amount` tokens to the `dst` address


```solidity
function transfer(address dst, uint256 amount) external override nonReentrant returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dst`|`address`|The address of the recipient|
|`amount`|`uint256`|The number of tokens to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the transfer was successful or not|


### transferFrom

Transfers `amount` tokens from the `src` address to the `dst` address


```solidity
function transferFrom(address src, address dst, uint256 amount) external override nonReentrant returns (bool);
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
|`<none>`|`bool`|Whether the transfer was successful or not|


### approve

Approves `spender` to spend `amount` tokens on behalf of the caller


```solidity
function approve(address spender, uint256 amount) external override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|The address authorized to spend tokens|
|`amount`|`uint256`|The number of tokens to approve|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the approval was successful or not|


### totalBorrowsCurrent

Returns the total amount of borrows, accounting for interest


```solidity
function totalBorrowsCurrent() external override nonReentrant returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount of borrows|


### borrowBalanceCurrent

Returns the current borrow balance for `account`, accounting for interest


```solidity
function borrowBalanceCurrent(address account) external override nonReentrant returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to query the borrow balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current borrow balance|


### exchangeRateCurrent

Returns the current exchange rate, with interest accrued


```solidity
function exchangeRateCurrent() public override nonReentrant returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current exchange rate|


### seize

Transfers collateral tokens (this market) to the liquidator.

*Will fail unless called by another mToken during the process of liquidation.
Its absolutely critical to use msg.sender as the borrowed mToken and not a parameter.*


```solidity
function seize(address liquidator, address borrower, uint256 seizeTokens) external override nonReentrant;
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
function reduceReserves(uint256 reduceAmount) external override nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reduceAmount`|`uint256`|Amount of reduction to reserves|


### _borrowBalanceStored

Return the borrow balance of account based on stored data


```solidity
function _borrowBalanceStored(address account) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address whose balance should be calculated|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|(error code, the calculated balance or 0 if error code is non-zero)|


### _mint

Sender supplies assets into the market and receives mTokens in exchange

*Accrues interest whether or not the operation succeeds, unless reverted*


```solidity
function _mint(address user, address receiver, uint256 mintAmount, uint256 minAmountOut, bool doTransfer)
    internal
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`receiver`|`address`||
|`mintAmount`|`uint256`|The amount of the underlying asset to supply|
|`minAmountOut`|`uint256`|The minimum amount to be received|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _redeem

Sender redeems mTokens in exchange for the underlying asset

*Accrues interest whether or not the operation succeeds, unless reverted*


```solidity
function _redeem(address user, uint256 redeemTokens, bool doTransfer)
    internal
    nonReentrant
    returns (uint256 underlyingAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`redeemTokens`|`uint256`|The number of mTokens to redeem into underlying|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _redeemUnderlying

Sender redeems mTokens in exchange for a specified amount of underlying asset

*Accrues interest whether or not the operation succeeds, unless reverted*


```solidity
function _redeemUnderlying(address user, uint256 redeemAmount, bool doTransfer) internal nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`redeemAmount`|`uint256`|The amount of underlying to receive from redeeming mTokens|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _borrow

Sender borrows assets from the protocol to their own address


```solidity
function _borrow(address user, uint256 borrowAmount, bool doTransfer) internal nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`borrowAmount`|`uint256`|The amount of the underlying asset to borrow|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _borrowWithReceiver

Sender borrows assets from the protocol to their own address


```solidity
function _borrowWithReceiver(address user, address receiver, uint256 borrowAmount) internal nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`receiver`|`address`|The underlying receiver address|
|`borrowAmount`|`uint256`|The amount of the underlying asset to borrow|


### _repay

Sender repays their own borrow


```solidity
function _repay(uint256 repayAmount, bool doTransfer) internal nonReentrant returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`repayAmount`|`uint256`|The amount to repay, or `type(uint256).max` for the full outstanding amount|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _repayBehalf

Sender repays a borrow belonging to borrower


```solidity
function _repayBehalf(address borrower, uint256 repayAmount, bool doTransfer) internal nonReentrant returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address`|the account with the debt being payed off|
|`repayAmount`|`uint256`|The amount to repay, or `type(uint256).max` for the full outstanding amount|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _liquidate

The sender liquidates the borrowers collateral.
The collateral seized is transferred to the liquidator.


```solidity
function _liquidate(
    address liquidator,
    address borrower,
    uint256 repayAmount,
    address mTokenCollateral,
    bool doTransfer
) internal nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidator`|`address`|The liquidator address|
|`borrower`|`address`|The borrower of this mToken to be liquidated|
|`repayAmount`|`uint256`|The amount of the underlying borrowed asset to repay|
|`mTokenCollateral`|`address`|The market in which to seize collateral from the borrower|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _seize

Transfers collateral tokens (this market) to the liquidator.

*Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another mToken.
Its absolutely critical to use msg.sender as the seizer mToken and not a parameter.*


```solidity
function _seize(address seizerToken, address liquidator, address borrower, uint256 seizeTokens) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`seizerToken`|`address`|The contract seizing the collateral (i.e. borrowed mToken)|
|`liquidator`|`address`|The account receiving seized collateral|
|`borrower`|`address`|The account having collateral seized|
|`seizeTokens`|`uint256`|The number of mTokens to seize|


### _addReserves

Accrues interest and reduces reserves by transferring from msg.sender


```solidity
function _addReserves(uint256 addAmount) internal nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addAmount`|`uint256`|Amount of addition to reserves|


### __liquidate

The liquidator liquidates the borrowers collateral.
The collateral seized is transferred to the liquidator.


```solidity
function __liquidate(
    address liquidator,
    address borrower,
    uint256 repayAmount,
    address mTokenCollateral,
    bool doTransfer
) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidator`|`address`|The address repaying the borrow and seizing collateral|
|`borrower`|`address`|The borrower of this mToken to be liquidated|
|`repayAmount`|`uint256`|The amount of the underlying borrowed asset to repay|
|`mTokenCollateral`|`address`|The market in which to seize collateral from the borrower|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### __repay

Borrows are repaid by another user (possibly the borrower).


```solidity
function __repay(address payer, address borrower, uint256 repayAmount, bool doTransfer) private returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`payer`|`address`|the account paying off the borrow|
|`borrower`|`address`|the account with the debt being payed off|
|`repayAmount`|`uint256`|the amount of underlying tokens being returned, or `type(uint256).max` for the full outstanding amount|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### __borrow

Users borrow assets from the protocol to their own address


```solidity
function __borrow(address payable borrower, address payable receiver, uint256 borrowAmount, bool doTransfer) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address payable`||
|`receiver`|`address payable`||
|`borrowAmount`|`uint256`|The amount of the underlying asset to borrow|
|`doTransfer`|`bool`||


### __redeem


```solidity
function __redeem(address payable redeemer, uint256 redeemTokensIn, uint256 redeemAmountIn, bool doTransfer)
    private
    returns (uint256 redeemAmount);
```

### __mint

User supplies assets into the market and receives mTokens in exchange

*Assumes interest has already been accrued up to the current block*


```solidity
function __mint(address minter, address receiver, uint256 mintAmount, uint256 minAmountOut, bool doTransfer) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|The address of the account which is supplying the assets|
|`receiver`|`address`|The address of the account which is receiving the assets|
|`mintAmount`|`uint256`|The amount of the underlying asset to supply|
|`minAmountOut`|`uint256`|The min amount to be received|
|`doTransfer`|`bool`|If an actual transfer should be performed|


### _transferTokens

Transfer `tokens` tokens from `src` to `dst` by `spender`

*Called by both `transfer` and `transferFrom` internally*


```solidity
function _transferTokens(address spender, address src, address dst, uint256 tokens) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|The address of the account performing the transfer|
|`src`|`address`|The address of the source account|
|`dst`|`address`|The address of the destination account|
|`tokens`|`uint256`|The number of tokens to transfer|


