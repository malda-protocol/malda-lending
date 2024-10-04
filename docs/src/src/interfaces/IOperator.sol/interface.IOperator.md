# IOperator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/b62e113034d94e880ebb241b8fad49eb27118646/src\interfaces\IOperator.sol)


## Functions
### rolesOpeartor

Roles manager


```solidity
function rolesOpeartor() external view returns (IRoles);
```

### oracleOperator

Oracle which gives the price of any given asset


```solidity
function oracleOperator() external view returns (address);
```

### closeFactorMantissa

Multiplier used to calculate the maximum repayAmount when liquidating a borrow


```solidity
function closeFactorMantissa() external view returns (uint256);
```

### liquidationIncentiveMantissa

Multiplier representing the discount on collateral that a liquidator receives


```solidity
function liquidationIncentiveMantissa() external view returns (uint256);
```

### getAssetsIn

Returns the assets an account has entered


```solidity
function getAssetsIn(address _user) external view returns (address[] memory mTokens);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|The address of the account to pull assets for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|A dynamic list with the assets the account has entered|


### getAllMarkets

A list of all markets


```solidity
function getAllMarkets() external view returns (address[] memory mTokens);
```

### borrowCaps

Borrow caps enforced by borrowAllowed for each mToken address. Defaults to zero which corresponds to unlimited borrowing.


```solidity
function borrowCaps(address _mToken) external view returns (uint256);
```

### supplyCaps

Supply caps enforced by supplyAllowed for each mToken address. Defaults to zero which corresponds to unlimited supplying.


```solidity
function supplyCaps(address _mToken) external view returns (uint256);
```

### rewardDistributor

Reward Distributor to markets supply and borrow (including protocol token)


```solidity
function rewardDistributor() external view returns (address);
```

### checkMembership

Returns whether the given account is entered in the given asset


```solidity
function checkMembership(address account, address mToken) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the account to check|
|`mToken`|`address`|The mToken to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the account is in the asset, otherwise false.|


### getAccountLiquidity

Determine the current account liquidity wrt collateral requirements


```solidity
function getAccountLiquidity(address account) external view returns (uint256, uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|account liquidity in excess of collateral requirements, account shortfall below collateral requirements)|
|`<none>`|`uint256`||


### getHypotheticalAccountLiquidity

Determine what the account liquidity would be if the given amounts were redeemed/borrowed


```solidity
function getHypotheticalAccountLiquidity(
    address account,
    address mTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount
) external view returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to determine liquidity for|
|`mTokenModify`|`address`|The market to hypothetically redeem/borrow in|
|`redeemTokens`|`uint256`|The number of tokens to hypothetically redeem|
|`borrowAmount`|`uint256`|The amount of underlying to hypothetically borrow|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|hypothetical account liquidity in excess of collateral requirements, hypothetical account shortfall below collateral requirements)|
|`<none>`|`uint256`||


### liquidateCalculateSeizeTokens

Calculate number of tokens of collateral asset to seize given an underlying amount

*Used in liquidation (called in mTokenBorrowed.liquidate)*


```solidity
function liquidateCalculateSeizeTokens(address mTokenBorrowed, address mTokenCollateral, uint256 actualRepayAmount)
    external
    view
    returns (uint256);
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
|`<none>`|`uint256`|number of mTokenCollateral tokens to be seized in a liquidation|


### activate

Add assets to be included in account liquidity calculation


```solidity
function activate(address[] calldata _mTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mTokens`|`address[]`|The list of addresses of the mToken markets to be enabled|


### deactivate

Removes asset from sender's account liquidity calculation

*Sender must not have an outstanding borrow balance in the asset,
or be providing necessary collateral for an outstanding borrow.*


```solidity
function deactivate(address _mToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|The address of the asset to be removed|


