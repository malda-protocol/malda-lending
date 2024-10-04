# mTokenDefenser
[Git Source](https://github.com/malda-protocol/malda-lending/blob/00d040411754d9ec62fde1c26b93be292ca3e328/src\mToken\mTokenDefenser.sol)

**Inherits:**
[mTokenConfiguration](/src\mToken\mTokenConfiguration.sol\abstract.mTokenConfiguration.md)


## Functions
### _beforeMint

Checks if the account should be allowed to mint tokens in the given market


```solidity
function _beforeMint(address mToken, address minter, uint256 mintAmount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the mint against|
|`minter`|`address`|The account which would get the minted tokens|
|`mintAmount`|`uint256`|The amount of underlying being supplied to the market in exchange for tokens|


### _afterMint

Defense hook for mint


```solidity
function _afterMint(address mToken, address minter, uint256 mintAmount, uint256 mintTokens) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being minted|
|`minter`|`address`|The address minting the tokens|
|`mintAmount`|`uint256`|The amount of the underlying asset being minted|
|`mintTokens`|`uint256`|The number of tokens being minted|


### _beforeMintExternal

Checks if the account should be allowed to mint tokens in the given market


```solidity
function _beforeMintExternal(address mToken, address minter, uint256 mintAmount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the mint against|
|`minter`|`address`|The account which would get the minted tokens|
|`mintAmount`|`uint256`|The amount of underlying being supplied to the market in exchange for tokens|


### _beforeRedeem

Redeem **

Checks if the account should be allowed to redeem tokens in the given market


```solidity
function _beforeRedeem(address mToken, address redeemer, uint256 redeemTokens) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the redeem against|
|`redeemer`|`address`|The account which would redeem the tokens|
|`redeemTokens`|`uint256`|The number of mToken to exchange for the underlying asset in the market|


### _afterRedeem

Validates redeem and reverts on rejection. May emit logs.


```solidity
function _afterRedeem(address mToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being redeemed|
|`redeemer`|`address`|The address redeeming the tokens|
|`redeemAmount`|`uint256`|The amount of the underlying asset being redeemed|
|`redeemTokens`|`uint256`|The number of tokens being redeemed|


### _beforeBorrow

Borrow **

Checks if the account should be allowed to borrow the underlying asset of the given market


```solidity
function _beforeBorrow(address mToken, address borrower, uint256 borrowAmount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the borrow against|
|`borrower`|`address`|The account which would borrow the asset|
|`borrowAmount`|`uint256`|The amount of underlying the account would borrow|


### _afterBorrow

Validates borrow and reverts on rejection. May emit logs.


```solidity
function _afterBorrow(address mToken, address borrower, uint256 borrowAmount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset whose underlying is being borrowed|
|`borrower`|`address`|The address borrowing the underlying|
|`borrowAmount`|`uint256`|The amount of the underlying asset requested to borrow|


### _beforeBorrowExternal

Checks if the account should be allowed to borrow the underlying asset of the given market


```solidity
function _beforeBorrowExternal(address mToken, address borrower, uint256 borrowAmount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the borrow against|
|`borrower`|`address`|The account which would borrow the asset|
|`borrowAmount`|`uint256`|The amount of underlying the account would borrow|


### _beforeRepay

Repay **

Checks if the account should be allowed to repay a borrow in the given market


```solidity
function _beforeRepay(address mToken, address payer, address borrower, uint256 repayAmount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the repay against|
|`payer`|`address`|The account which would repay the asset|
|`borrower`|`address`|The account which would borrowed the asset|
|`repayAmount`|`uint256`|The amount of the underlying asset the account would repay|


### _afterRepay

Validates repayBorrow and reverts on rejection. May emit logs.


```solidity
function _afterRepay(address mToken, address payer, address borrower, uint256 actualRepayAmount, uint256 borrowerIndex)
    internal
    virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being repaid|
|`payer`|`address`|The address repaying the borrow|
|`borrower`|`address`|The address of the borrower|
|`actualRepayAmount`|`uint256`|The amount of underlying being repaid|
|`borrowerIndex`|`uint256`||


### _beforeLiquidate

Liquidate **

Checks if the liquidation should be allowed to occur


```solidity
function _beforeLiquidate(
    address mTokenBorrowed,
    address mTokenCollateral,
    address liquidator,
    address borrower,
    uint256 repayAmount
) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|
|`repayAmount`|`uint256`|The amount of underlying being repaid|


### _afterLiquidate

Validates liquidateBorrow and reverts on rejection. May emit logs.


```solidity
function _afterLiquidate(
    address mTokenBorrowed,
    address mTokenCollateral,
    address liquidator,
    address borrower,
    uint256 actualRepayAmount,
    uint256 seizeTokens
) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|
|`actualRepayAmount`|`uint256`|The amount of underlying being repaid|
|`seizeTokens`|`uint256`||


### _beforeSeize

Seize **

Checks if the seizing of assets should be allowed to occur


```solidity
function _beforeSeize(
    address mTokenCollateral,
    address mTokenBorrowed,
    address liquidator,
    address borrower,
    uint256 seizeTokens
) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|
|`seizeTokens`|`uint256`|The number of collateral tokens to seize|


### _afterSeize

Validates seize and reverts on rejection. May emit logs.


```solidity
function _afterSeize(
    address mTokenCollateral,
    address mTokenBorrowed,
    address liquidator,
    address borrower,
    uint256 seizeTokens
) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|
|`seizeTokens`|`uint256`|The number of collateral tokens to seize|


### _beforeTransfer

Transfer **

Checks if the account should be allowed to transfer tokens in the given market


```solidity
function _beforeTransfer(address mToken, address src, address dst, uint256 transferTokens) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the transfer against|
|`src`|`address`|The account which sources the tokens|
|`dst`|`address`|The account which receives the tokens|
|`transferTokens`|`uint256`|The number of mTokens to transfer|


### _afterTransfer

Validates transfer and reverts on rejection. May emit logs.


```solidity
function _afterTransfer(address mToken, address src, address dst, uint256 transferTokens) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being transferred|
|`src`|`address`|The account which sources the tokens|
|`dst`|`address`|The account which receives the tokens|
|`transferTokens`|`uint256`|The number of mTokens to transfer|


