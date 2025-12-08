# IMendiMarket
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/migration/IMigrator.sol)

**Author:**
Merge Layers Inc.

Interface for legacy Mendi market interactions


## Functions
### repayBorrow

Repays a borrow


```solidity
function repayBorrow(uint256 repayAmount) external returns (uint256 repaidAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`repayAmount`|`uint256`|Amount to repay or type(uint256).max|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`repaidAmount`|`uint256`|Actual repaid amount|


### repayBorrowBehalf

Repays a borrow on behalf of borrower


```solidity
function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256 repaidAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`borrower`|`address`|Borrower address|
|`repayAmount`|`uint256`|Amount to repay|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`repaidAmount`|`uint256`|Actual repaid amount|


### redeemUnderlying

Redeems underlying for given amount


```solidity
function redeemUnderlying(uint256 redeemAmount) external returns (uint256 redeemed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`redeemAmount`|`uint256`|Amount to redeem|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`redeemed`|`uint256`|Amount of underlying redeemed|


### redeem

Redeems tokens


```solidity
function redeem(uint256 amount) external returns (uint256 redeemed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of tokens to redeem|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`redeemed`|`uint256`|Amount redeemed|


### balanceOfUnderlying

Returns underlying balance of sender


```solidity
function balanceOfUnderlying(address sender) external returns (uint256 balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|Underlying balance|


### underlying

Returns underlying asset address


```solidity
function underlying() external view returns (address asset);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Underlying token|


### balanceOf

Returns token balance of sender


```solidity
function balanceOf(address sender) external view returns (uint256 tokenBalance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenBalance`|`uint256`|Token balance|


### borrowBalanceStored

Returns stored borrow balance


```solidity
function borrowBalanceStored(address sender) external view returns (uint256 borrowBalance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|Address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`borrowBalance`|`uint256`|Borrow balance|


