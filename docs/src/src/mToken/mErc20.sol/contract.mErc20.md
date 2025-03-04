# mErc20
[Git Source](https://github.com/malda-protocol/malda-lending/blob/6ea8fcbab45a04b689cc49c81c736245cab92c98/src\mToken\mErc20.sol)

**Inherits:**
[mToken](/src\mToken\mToken.sol\abstract.mToken.md), [ImErc20](/src\interfaces\ImErc20.sol\interface.ImErc20.md)

mTokens which wrap an EIP-20 underlying


## State Variables
### underlying
Underlying asset for this mToken


```solidity
address public underlying;
```


## Functions
### initialize

Initialize the new money market


```solidity
function initialize(
    address underlying_,
    address operator_,
    address interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_
) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`underlying_`|`address`|The address of the underlying asset|
|`operator_`|`address`|The address of the Operator|
|`interestRateModel_`|`address`|The address of the interest rate model|
|`initialExchangeRateMantissa_`|`uint256`|The initial exchange rate, scaled by 1e18|
|`name_`|`string`|ERC-20 name of this token|
|`symbol_`|`string`|ERC-20 symbol of this token|
|`decimals_`|`uint8`|ERC-20 decimal precision of this token|


### delegateMaldaLikeTo

Admin call to delegate the votes of the MALDA-like underlying

*mTokens whose underlying are not  should revert here*


```solidity
function delegateMaldaLikeTo(address delegatee) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`delegatee`|`address`|The address to delegate votes to|


### sweepToken

A public function to sweep accidental ERC-20 transfers to this contract. Tokens are sent to admin (timelock)


```solidity
function sweepToken(IERC20 token) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the ERC-20 token to sweep|


### mint

Sender supplies assets into the market and receives mTokens in exchange

*Accrues interest whether or not the operation succeeds, unless reverted*


```solidity
function mint(uint256 mintAmount, address receiver, uint256 minAmountOut) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mintAmount`|`uint256`|The amount of the underlying asset to supply|
|`receiver`|`address`|The mTokens receiver|
|`minAmountOut`|`uint256`|The min amounts to be received|


### redeem

Sender redeems mTokens in exchange for the underlying asset

*Accrues interest whether or not the operation succeeds, unless reverted*


```solidity
function redeem(uint256 redeemTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemTokens`|`uint256`|The number of mTokens to redeem into underlying|


### redeemUnderlying

Sender redeems mTokens in exchange for a specified amount of underlying asset

*Accrues interest whether or not the operation succeeds, unless reverted*


```solidity
function redeemUnderlying(uint256 redeemAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemAmount`|`uint256`|The amount of underlying to redeem|


### borrow

Sender borrows assets from the protocol to their own address


```solidity
function borrow(uint256 borrowAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrowAmount`|`uint256`|The amount of the underlying asset to borrow|


### repay

Sender repays their own borrow


```solidity
function repay(uint256 repayAmount) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`repayAmount`|`uint256`|The amount to repay, or type(uint256).max for the full outstanding amount|


### repayBehalf

Sender repays a borrow belonging to borrower


```solidity
function repayBehalf(address borrower, uint256 repayAmount) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address`|the account with the debt being payed off|
|`repayAmount`|`uint256`|The amount to repay, or type(uint256).max for the full outstanding amount|


### liquidate

The sender liquidates the borrowers collateral.
The collateral seized is transferred to the liquidator.


```solidity
function liquidate(address borrower, uint256 repayAmount, address mTokenCollateral) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address`|The borrower of this mToken to be liquidated|
|`repayAmount`|`uint256`|The amount of the underlying borrowed asset to repay|
|`mTokenCollateral`|`address`|The market in which to seize collateral from the borrower|


### addReserves

The sender adds to reserves.


```solidity
function addReserves(uint256 addAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addAmount`|`uint256`|The amount fo underlying token to add as reserves|


### _getCashPrior

Gets balance of this contract in terms of the underlying

*This excludes the value of the current message, if any*


```solidity
function _getCashPrior() internal view virtual override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The quantity of underlying tokens owned by this contract|


### _doTransferIn

*Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
This may revert due to insufficient balance or insufficient allowance.*


```solidity
function _doTransferIn(address from, uint256 amount) internal virtual override returns (uint256);
```

### _doTransferOut

*Performs a transfer out, ideally returning an explanatory error code upon failure rather than reverting.
If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.*


```solidity
function _doTransferOut(address payable to, uint256 amount) internal virtual override;
```

## Errors
### mErc20_TokenNotValid

```solidity
error mErc20_TokenNotValid();
```

