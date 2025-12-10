# mErc20
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/mToken/mErc20.sol)

**Inherits:**
[mToken](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/mToken/mToken.sol/abstract.mToken.md), [ImErc20](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/ImErc20.sol/interface.ImErc20.md)

**Author:**
Merge Layers Inc.

mTokens which wrap an EIP-20 underlying


## State Variables
### underlying
Underlying asset for this mToken


```solidity
address public underlying
```


## Functions
### sweepToken

A public function to sweep accidental ERC-20 transfers to this contract. Tokens are sent to admin (timelock)


```solidity
function sweepToken(IERC20 token, uint256 amount) external onlyAdmin;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IERC20`|The address of the ERC-20 token to sweep|
|`amount`|`uint256`|The amount of tokens to sweep|


### mint

Sender supplies assets into the market and receives mTokens in exchange

Accrues interest whether or not the operation succeeds, unless reverted


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

Accrues interest whether or not the operation succeeds, unless reverted


```solidity
function redeem(uint256 redeemTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemTokens`|`uint256`|The number of mTokens to redeem into underlying|


### redeemUnderlying

Sender redeems mTokens in exchange for a specified amount of underlying asset

Accrues interest whether or not the operation succeeds, unless reverted


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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|repaymentAmount The actual amount repaid|


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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|repaymentAmount The actual amount repaid|


### liquidate

The sender liquidates the borrowers collateral and transfers seized assets to the liquidator


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

The sender adds to reserves


```solidity
function addReserves(uint256 addAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addAmount`|`uint256`|The amount fo underlying token to add as reserves|


### _initializeMErc20

Initialize the new money market


```solidity
function _initializeMErc20(
    address underlying_,
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
|`underlying_`|`address`|The address of the underlying asset|
|`operator_`|`address`|The address of the Operator|
|`interestRateModel_`|`address`|The address of the interest rate model|
|`initialExchangeRateMantissa_`|`uint256`|The initial exchange rate, scaled by 1e18|
|`name_`|`string`|ERC-20 name of this token|
|`symbol_`|`string`|ERC-20 symbol of this token|
|`decimals_`|`uint8`|ERC-20 decimal precision of this token|


### _doTransferIn

Performs a transfer in, reverting upon failure


```solidity
function _doTransferIn(address from, uint256 amount) internal virtual override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Sender address|
|`amount`|`uint256`|Amount to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Amount actually transferred to the protocol|


### _doTransferOut

Performs a transfer out to a recipient


```solidity
function _doTransferOut(address payable to, uint256 amount) internal virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address payable`|Recipient address|
|`amount`|`uint256`|Amount to transfer|


### _getCashPrior

Gets balance of this contract in terms of the underlying

This excludes the value of the current message, if any


```solidity
function _getCashPrior() internal view virtual override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The quantity of underlying tokens owned by this contract|


## Errors
### mErc20_TokenNotValid
Error thrown when token is not valid


```solidity
error mErc20_TokenNotValid();
```

