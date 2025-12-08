# LiquidationHelper
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/utils/LiquidationHelper.sol)

**Author:**
Malda Protocol

View helper that computes whether a borrower can be liquidated and the repay amount.


## Functions
### getBorrowerPosition

Computes liquidation eligibility for a borrower on a market


```solidity
function getBorrowerPosition(address borrower, address market)
    external
    view
    returns (bool shouldLiquidate, uint256 repayAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address`|Address of the borrower|
|`market`|`address`|Market address implementing ImToken|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shouldLiquidate`|`bool`|True if borrower is below collateral requirements|
|`repayAmount`|`uint256`|Max repay amount according to close factor|


