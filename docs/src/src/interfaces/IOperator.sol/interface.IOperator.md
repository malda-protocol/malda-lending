# IOperator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/034fc0e2fca466a96bdb4527b71e15ddea321646/src/interfaces/IOperator.sol)

**Author:**
Merge Layers Inc.

Core Operator contract surface


## Functions
### userWhitelisted

Returns true/false for user


```solidity
function userWhitelisted(address _user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|Address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|whitelisted True if user is whitelisted|


### limitPerTimePeriod

Should return outflow limit


```solidity
function limitPerTimePeriod() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|limit Outflow limit per period|


### cumulativeOutflowVolume

Should return outflow volume


```solidity
function cumulativeOutflowVolume() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|volume Current outflow volume|


### lastOutflowResetTimestamp

Should return last reset time for outflow check


```solidity
function lastOutflowResetTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|lastReset Timestamp of last reset|


### outflowResetTimeWindow

Should return the outflow volume time window


```solidity
function outflowResetTimeWindow() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|window Outflow window|


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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|paused True if paused|


### rolesOperator

Roles


```solidity
function rolesOperator() external view returns (IRoles);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IRoles`|roles Roles contract|


### blacklistOperator

Blacklist


```solidity
function blacklistOperator() external view returns (IBlacklister);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IBlacklister`|blacklister Blacklist operator|


### oracleOperator

Oracle which gives the price of any given asset


```solidity
function oracleOperator() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|oracle Oracle address|


### closeFactorMantissa

Multiplier used to calculate the maximum repayAmount when liquidating a borrow


```solidity
function closeFactorMantissa() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|closeFactor Close factor mantissa|


### liquidationIncentiveMantissa

Multiplier representing the discount on collateral that a liquidator receives


```solidity
function liquidationIncentiveMantissa(address market) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|Market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|incentive Discount mantissa|


### isMarketListed

Returns true/false


```solidity
function isMarketListed(address market) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|Market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|listed True if market is listed|


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
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|List of markets|


### borrowCaps

Borrow caps enforced by borrowAllowed for each mToken address.

Defaults to zero which corresponds to unlimited borrowing.


```solidity
function borrowCaps(address _mToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|Market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|cap Borrow cap|


### supplyCaps

Supply caps enforced by supplyAllowed for each mToken address.

Defaults to zero which corresponds to unlimited supplying.


```solidity
function supplyCaps(address _mToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|Market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|cap Supply cap|


### minBorrowSize

Supply caps enforced by supplyAllowed for each mToken address.

Defaults to zero which corresponds to unlimited borrowing.


```solidity
function minBorrowSize(address _mToken) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|Market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|minimum Minimum borrow size|


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


### getHypotheticalAccountLiquidity

Determine what the account liquidity would be if the given amounts were redeemed/borrowed


```solidity
function getHypotheticalAccountLiquidity(
    address account,
    address mTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount
) external view returns (uint256 liquidity, uint256 shortfall);
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
|`liquidity`|`uint256`|Account liquidity in excess of collateral requirements|
|`shortfall`|`uint256`|Account shortfall below collateral requirements|


### getUSDValueForAllMarkets

Returns USD value for all markets


```solidity
function getUSDValueForAllMarkets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|usdValue Total USD value|


### isDeprecated

Returns true if the given mToken market has been deprecated

All borrows in a deprecated mToken market can be immediately liquidated


```solidity
function isDeprecated(address mToken) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to check if deprecated|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|deprecated True if deprecated|


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

Sender must not have an outstanding borrow balance in the asset,
and must not be providing necessary collateral for an outstanding borrow.


```solidity
function exitMarket(address _mToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|The address of the asset to be removed|


