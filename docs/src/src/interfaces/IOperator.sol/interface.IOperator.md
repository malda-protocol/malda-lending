# IOperator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\IOperator.sol)


## Functions
### userWhitelisted

Returns true/false for user


```solidity
function userWhitelisted(address _user) external view returns (bool);
```

### isOperator

Should return true


```solidity
function isOperator() external view returns (bool);
```

### limitPerTimePeriod

Should return outflow limit


```solidity
function limitPerTimePeriod() external view returns (uint256);
```

### cumulativeOutflowVolume

Should return outflow volume


```solidity
function cumulativeOutflowVolume() external view returns (uint256);
```

### lastOutflowResetTimestamp

Should return last reset time for outflow check


```solidity
function lastOutflowResetTimestamp() external view returns (uint256);
```

### outflowResetTimeWindow

Should return the outflow volume time window


```solidity
function outflowResetTimeWindow() external view returns (uint256);
```

### isPaused

Returns if operation is paused


```solidity
function isPaused(address mToken, ImTokenOperationTypes.OperationType _type) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The mToken to check|
|`_type`|`ImTokenOperationTypes.OperationType`|the operation type|


### rolesOperator

Roles


```solidity
function rolesOperator() external view returns (IRoles);
```

### blacklistOperator

Blacklist


```solidity
function blacklistOperator() external view returns (IBlacklister);
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
function liquidationIncentiveMantissa(address market) external view returns (uint256);
```

### isMarketListed

Returns true/false


```solidity
function isMarketListed(address market) external view returns (bool);
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


### getUSDValueForAllMarkets

Returns USD value for all markets


```solidity
function getUSDValueForAllMarkets() external view returns (uint256);
```

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
|`mTokenBorrowed`|`address`|The address of the borrowed mToken|
|`mTokenCollateral`|`address`|The address of the collateral mToken|
|`actualRepayAmount`|`uint256`|The amount of mTokenBorrowed underlying to convert into mTokenCollateral tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|number of mTokenCollateral tokens to be seized in a liquidation|


### isDeprecated

Returns true if the given mToken market has been deprecated

*All borrows in a deprecated mToken market can be immediately liquidated*


```solidity
function isDeprecated(address mToken) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to check if deprecated|


### setPaused

Set pause for a specific operation


```solidity
function setPaused(address mToken, ImTokenOperationTypes.OperationType _type, bool state) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market token address|
|`_type`|`ImTokenOperationTypes.OperationType`|The pause operation type|
|`state`|`bool`|The pause operation status|


### enterMarkets

Add assets to be included in account liquidity calculation


```solidity
function enterMarkets(address[] calldata _mTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mTokens`|`address[]`|The list of addresses of the mToken markets to be enabled|


### enterMarketsWithSender

Add asset (msg.sender) to be included in account liquidity calculation


```solidity
function enterMarketsWithSender(address _account) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The account to add for|


### exitMarket

Removes asset from sender's account liquidity calculation

*Sender must not have an outstanding borrow balance in the asset,
or be providing necessary collateral for an outstanding borrow.*


```solidity
function exitMarket(address _mToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|The address of the asset to be removed|


### claimMalda

Claim all the MALDA accrued by holder in all markets


```solidity
function claimMalda(address holder) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address to claim MALDA for|


### claimMalda

Claim all the MALDA accrued by holder in the specified markets


```solidity
function claimMalda(address holder, address[] memory mTokens) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address to claim MALDA for|
|`mTokens`|`address[]`|The list of markets to claim MALDA in|


### claimMalda

Claim all MALDA accrued by the holders


```solidity
function claimMalda(address[] memory holders, address[] memory mTokens, bool borrowers, bool suppliers) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holders`|`address[]`|The addresses to claim MALDA for|
|`mTokens`|`address[]`|The list of markets to claim MALDA in|
|`borrowers`|`bool`|Whether or not to claim MALDA earned by borrowing|
|`suppliers`|`bool`|Whether or not to claim MALDA earned by supplying|


