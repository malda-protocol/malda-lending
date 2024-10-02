# ImTokenHelper
[Git Source](https://github.com/malda-protocol/malda-lending/blob/179a048ba4fdf7caff4add1e6a0986ba27ae405c/src\interfaces\ImTokenHelper.sol)


## Functions
### isMintValid

Mint **

Checks if the account should be allowed to mint tokens in the given market


```solidity
function isMintValid(address mToken, address minter, uint256 mintAmount, uint256 mintTokens)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being minted|
|`minter`|`address`|The address minting the tokens|
|`mintAmount`|`uint256`|The amount of the underlying asset being minted|
|`mintTokens`|`uint256`|The number of tokens being minted|


### isRedeemValid

Redeem **

Checks if the account should be allowed to redeem tokens in the given market


```solidity
function isRedeemValid(address mToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being redeemed|
|`redeemer`|`address`|The address redeeming the tokens|
|`redeemAmount`|`uint256`|The amount of the underlying asset being redeemed|
|`redeemTokens`|`uint256`|The number of tokens being redeemed|


### isBorrowValid

Borrow **

Checks if the account should be allowed to borrow the underlying asset of the given market


```solidity
function isBorrowValid(address mToken, address borrower, uint256 borrowAmount) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the borrow against|
|`borrower`|`address`|The account which would borrow the asset|
|`borrowAmount`|`uint256`|The amount of underlying the account would borrow|


### isRepayValid

Repay **

Checks if the account should be allowed to repay a borrow in the given market


```solidity
function isRepayValid(address mToken, address payer, address borrower, uint256 repayAmount)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the repay against|
|`payer`|`address`|The account which would repay the asset|
|`borrower`|`address`|The account which would borrowed the asset|
|`repayAmount`|`uint256`|The amount of the underlying asset the account would repay|


### isLiquidateValid

Liquidate **

Checks if the liquidation should be allowed to occur


```solidity
function isLiquidateValid(
    address mTokenBorrowed,
    address mTokenCollateral,
    address liquidator,
    address borrower,
    uint256 repayAmount
) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|
|`repayAmount`|`uint256`|The amount of underlying being repaid|


### liquidateCalculateSeizeTokens

Calculate number of tokens of collateral asset to seize given an underlying amount

*Used in liquidation (called in mTokenBorrowed.liquidate)*


```solidity
function liquidateCalculateSeizeTokens(address mTokenBorrowed, address mTokenCollateral, uint256 actualRepayAmount)
    external
    view
    returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenBorrowed`|`address`|The address of the borrowed cToken|
|`mTokenCollateral`|`address`|The address of the collateral cToken|
|`actualRepayAmount`|`uint256`|The amount of mTokenBorrowed underlying to convert into mTokenCollateral tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|(errorCode, number of mTokenCollateral tokens to be seized in a liquidation)|
|`<none>`|`uint256`||


### isSeizeValid

Seize **

Checks if the seizing of assets should be allowed to occur


```solidity
function isSeizeValid(
    address mTokenCollateral,
    address mTokenBorrowed,
    address liquidator,
    address borrower,
    uint256 seizeTokens
) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|
|`seizeTokens`|`uint256`|The number of collateral tokens to seize|


### isTransferValid

Transfer **

Checks if the account should be allowed to transfer tokens in the given market


```solidity
function isTransferValid(address mToken, address src, address dst, uint256 transferTokens)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the transfer against|
|`src`|`address`|The account which sources the tokens|
|`dst`|`address`|The account which receives the tokens|
|`transferTokens`|`uint256`|The number of mTokens to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)|


