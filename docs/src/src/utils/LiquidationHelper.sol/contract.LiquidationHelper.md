# LiquidationHelper
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/utils/LiquidationHelper.sol)

**Title:**
Liquidation helper

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


