# IOperatorDefender
[Git Source](https://github.com/https://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@malda-protocol/malda-lending/blob/22e38d89bfe9c3bbd0459495952fb3409b4b0c16/src\interfaces\IOperator.sol)


## Functions
### beforeMTokenTransfer

Checks if the account should be allowed to transfer tokens in the given market


```solidity
function beforeMTokenTransfer(address mToken, address src, address dst, uint256 transferTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the transfer against|
|`src`|`address`|The account which sources the tokens|
|`dst`|`address`|The account which receives the tokens|
|`transferTokens`|`uint256`|The number of mTokens to transfer|


### beforeMTokenMint

Checks if the account should be allowed to mint tokens in the given market


```solidity
function beforeMTokenMint(address mToken, address minter) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the mint against|
|`minter`|`address`|The account which would get the minted tokens|


### afterMTokenMint

Validates mint and reverts on rejection. May emit logs.


```solidity
function afterMTokenMint(address mToken) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being minted|


### beforeMTokenRedeem

Checks if the account should be allowed to redeem tokens in the given market


```solidity
function beforeMTokenRedeem(address mToken, address redeemer, uint256 redeemTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the redeem against|
|`redeemer`|`address`|The account which would redeem the tokens|
|`redeemTokens`|`uint256`|The number of mTokens to exchange for the underlying asset in the market|


### beforeMTokenBorrow

Checks if the account should be allowed to borrow the underlying asset of the given market


```solidity
function beforeMTokenBorrow(address mToken, address borrower, uint256 borrowAmount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the borrow against|
|`borrower`|`address`|The account which would borrow the asset|
|`borrowAmount`|`uint256`|The amount of underlying the account would borrow|


### beforeMTokenRepay

Checks if the account should be allowed to repay a borrow in the given market


```solidity
function beforeMTokenRepay(address mToken, address borrower) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the repay against|
|`borrower`|`address`|The account which would borrowed the asset|


### beforeMTokenLiquidate

Checks if the liquidation should be allowed to occur


```solidity
function beforeMTokenLiquidate(address mTokenBorrowed, address mTokenCollateral, address borrower, uint256 repayAmount)
    external
    view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`borrower`|`address`|The address of the borrower|
|`repayAmount`|`uint256`|The amount of underlying being repaid|


### beforeMTokenSeize

Checks if the seizing of assets should be allowed to occur


```solidity
function beforeMTokenSeize(address mTokenCollateral, address mTokenBorrowed, address liquidator, address borrower)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|


