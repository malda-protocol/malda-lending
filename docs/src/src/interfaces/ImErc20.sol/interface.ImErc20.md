# ImErc20
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\ImErc20.sol)


## Functions
### mint

Sender supplies assets into the market and receives mTokens in exchange

*Accrues interest whether or not the operation succeeds, unless reverted*


```solidity
function mint(uint256 mintAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mintAmount`|`uint256`|The amount of the underlying asset to supply|


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
function repay(uint256 repayAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`repayAmount`|`uint256`|The amount to repay, or -1 for the full outstanding amount|


### repayBehalf

Sender repays a borrow belonging to borrower


```solidity
function repayBehalf(address borrower, uint256 repayAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address`|the account with the debt being payed off|
|`repayAmount`|`uint256`|The amount to repay, or -1 for the full outstanding amount|


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


