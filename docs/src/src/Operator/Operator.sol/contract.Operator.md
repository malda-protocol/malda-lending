# Operator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\Operator\Operator.sol)

**Inherits:**
[OperatorStorage](/src\Operator\OperatorStorage.sol\abstract.OperatorStorage.md), [ImTokenOperationTypes](/src\interfaces\ImToken.sol\interface.ImTokenOperationTypes.md), OwnableUpgradeable


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize


```solidity
function initialize(address _rolesOperator, address _blacklistOperator, address _rewardDistributor, address _admin)
    public
    initializer;
```

### onlyAllowedUser


```solidity
modifier onlyAllowedUser(address user);
```

### ifNotBlacklisted


```solidity
modifier ifNotBlacklisted(address user);
```

### setWhitelistedUser

Sets user whitelist status


```solidity
function setWhitelistedUser(address user, bool state) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`state`|`bool`|The new staate|


### enableWhitelist

Enable user whitelist


```solidity
function enableWhitelist() external onlyOwner;
```

### disableWhitelist

Disable user whitelist


```solidity
function disableWhitelist() external onlyOwner;
```

### setRolesOperator

Sets a new Operator for the market

*Admin function to set a new operator*


```solidity
function setRolesOperator(address _roles) external onlyOwner;
```

### setPriceOracle

Sets a new price oracle

*Admin function to set a new price oracle*


```solidity
function setPriceOracle(address newOracle) external onlyOwner;
```

### setCloseFactor

Sets the closeFactor used when liquidating borrows

*Admin function to set closeFactor*


```solidity
function setCloseFactor(uint256 newCloseFactorMantissa) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCloseFactorMantissa`|`uint256`|New close factor, scaled by 1e18|


### setCollateralFactor

Sets the collateralFactor for a market

*Admin function to set per-market collateralFactor*


```solidity
function setCollateralFactor(address mToken, uint256 newCollateralFactorMantissa) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to set the factor on|
|`newCollateralFactorMantissa`|`uint256`|The new collateral factor, scaled by 1e18|


### setLiquidationIncentive

Sets liquidationIncentive

*Admin function to set liquidationIncentive*


```solidity
function setLiquidationIncentive(address market, uint256 newLiquidationIncentiveMantissa) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`||
|`newLiquidationIncentiveMantissa`|`uint256`|New liquidationIncentive scaled by 1e18|


### supportMarket

Add the market to the markets mapping and set it as listed

*Admin function to set isListed and add support for the market*


```solidity
function supportMarket(address mToken) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The address of the market (token) to list|


### setOutflowVolumeTimeWindow

Sets outflow volume time window


```solidity
function setOutflowVolumeTimeWindow(uint256 newTimeWindow) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTimeWindow`|`uint256`|The new reset time window|


### setOutflowTimeLimitInUSD

Sets outflow volume limit

*when 0, it means there's no limit*


```solidity
function setOutflowTimeLimitInUSD(uint256 amount) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The new limit|


### resetOutflowVolume

Resets outflow volume


```solidity
function resetOutflowVolume() external onlyOwner;
```

### checkOutflowVolumeLimit

Verifies outflow volule limit


```solidity
function checkOutflowVolumeLimit(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The new limit|


### setMarketBorrowCaps

Set the given borrow caps for the given mToken markets. Borrowing that brings total borrows to or above borrow cap will revert.


```solidity
function setMarketBorrowCaps(address[] calldata mTokens, uint256[] calldata newBorrowCaps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|The addresses of the markets (tokens) to change the borrow caps for|
|`newBorrowCaps`|`uint256[]`|The new borrow cap values in underlying to be set. A value of 0 corresponds to unlimited borrowing.|


### setMarketSupplyCaps

Set the given supply caps for the given mToken markets. Supplying that brings total supply to or above supply cap will revert.


```solidity
function setMarketSupplyCaps(address[] calldata mTokens, uint256[] calldata newSupplyCaps) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|The addresses of the markets (tokens) to change the supply caps for|
|`newSupplyCaps`|`uint256[]`|The new supply cap values in underlying to be set. A value of 0 corresponds to unlimited supplying.|


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


### setRewardDistributor

Admin function to change the Reward Distributor


```solidity
function setRewardDistributor(address newRewardDistributor) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRewardDistributor`|`address`|The address of the new Reward Distributor|


### isOperator

Should return true


```solidity
function isOperator() external pure override returns (bool);
```

### isPaused

Returns if operation is paused


```solidity
function isPaused(address mToken, ImTokenOperationTypes.OperationType _type) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The mToken to check|
|`_type`|`ImTokenOperationTypes.OperationType`|the operation type|


### getAssetsIn

Returns the assets an account has entered


```solidity
function getAssetsIn(address _user) external view override returns (address[] memory mTokens);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_user`|`address`|The address of the account to pull assets for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|A dynamic list with the assets the account has entered|


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


### getAllMarkets

A list of all markets


```solidity
function getAllMarkets() external view returns (address[] memory mTokens);
```

### isDeprecated

Returns true if the given mToken market has been deprecated

*All borrows in a deprecated mToken market can be immediately liquidated*


```solidity
function isDeprecated(address mToken) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to check if deprecated|


### isMarketListed

Returns true/false


```solidity
function isMarketListed(address mToken) external view override returns (bool);
```

### getAccountLiquidity

Determine the current account liquidity wrt collateral requirements


```solidity
function getAccountLiquidity(address account) public view returns (uint256, uint256);
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
|`mTokenBorrowed`|`address`|The address of the borrowed mToken|
|`mTokenCollateral`|`address`|The address of the collateral mToken|
|`actualRepayAmount`|`uint256`|The amount of mTokenBorrowed underlying to convert into mTokenCollateral tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|number of mTokenCollateral tokens to be seized in a liquidation|


### enterMarkets

Add assets to be included in account liquidity calculation


```solidity
function enterMarkets(address[] calldata _mTokens) external override onlyAllowedUser(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mTokens`|`address[]`|The list of addresses of the mToken markets to be enabled|


### enterMarketsWithSender

Add asset (msg.sender) to be included in account liquidity calculation


```solidity
function enterMarketsWithSender(address _account) external override onlyAllowedUser(_account);
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
function exitMarket(address _mToken) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|The address of the asset to be removed|


### claimMalda

Claim all the MALDA accrued by holder in all markets


```solidity
function claimMalda(address holder) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address to claim MALDA for|


### claimMalda

Claim all the MALDA accrued by holder in the specified markets


```solidity
function claimMalda(address holder, address[] memory mTokens) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address to claim MALDA for|
|`mTokens`|`address[]`|The list of markets to claim MALDA in|


### claimMalda

Claim all MALDA accrued by the holders


```solidity
function claimMalda(address[] memory holders, address[] memory mTokens, bool borrowers, bool suppliers)
    external
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holders`|`address[]`|The addresses to claim MALDA for|
|`mTokens`|`address[]`|The list of markets to claim MALDA in|
|`borrowers`|`bool`|Whether or not to claim MALDA earned by borrowing|
|`suppliers`|`bool`|Whether or not to claim MALDA earned by supplying|


### getUSDValueForAllMarkets

Returns USD value for all markets


```solidity
function getUSDValueForAllMarkets() external view returns (uint256);
```

### beforeRebalancing

Checks if the account should be allowed to rebalance tokens


```solidity
function beforeRebalancing(address mToken) external view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the transfer against|


### beforeMTokenTransfer

Checks if the account should be allowed to transfer tokens in the given market


```solidity
function beforeMTokenTransfer(address mToken, address src, address dst, uint256 transferTokens)
    external
    override
    ifNotBlacklisted(src)
    ifNotBlacklisted(dst);
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
function beforeMTokenMint(address mToken, address minter)
    external
    override
    onlyAllowedUser(minter)
    ifNotBlacklisted(minter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the mint against|
|`minter`|`address`|The account which would get the minted tokens|


### afterMTokenMint

Validates mint and reverts on rejection. May emit logs.


```solidity
function afterMTokenMint(address mToken) external view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Asset being minted|


### beforeMTokenRedeem

Checks if the account should be allowed to redeem tokens in the given market


```solidity
function beforeMTokenRedeem(address mToken, address redeemer, uint256 redeemTokens)
    external
    override
    onlyAllowedUser(redeemer)
    ifNotBlacklisted(redeemer);
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
function beforeMTokenBorrow(address mToken, address borrower, uint256 borrowAmount)
    external
    override
    onlyAllowedUser(borrower)
    ifNotBlacklisted(borrower);
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
function beforeMTokenRepay(address mToken, address borrower) external onlyAllowedUser(borrower);
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
    view
    override
    onlyAllowedUser(borrower)
    ifNotBlacklisted(borrower);
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
    external
    override
    ifNotBlacklisted(liquidator)
    ifNotBlacklisted(borrower);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|
|`borrower`|`address`|The address of the borrower|


### _convertMarketAmountToUSDValue


```solidity
function _convertMarketAmountToUSDValue(uint256 amount, address mToken) internal view returns (uint256);
```

### _activateMarket


```solidity
function _activateMarket(address _mToken, address borrower) private;
```

### _beforeRedeem


```solidity
function _beforeRedeem(address mToken, address redeemer, uint256 redeemTokens) private view;
```

### _getHypotheticalAccountLiquidity


```solidity
function _getHypotheticalAccountLiquidity(
    address account,
    address mTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount
) private view returns (uint256, uint256);
```

### _updateMaldaSupplyIndex

Notify reward distributor for supply index update


```solidity
function _updateMaldaSupplyIndex(address mToken) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market whose supply index to update|


### _updateMaldaBorrowIndex

Notify reward distributor for borrow index update


```solidity
function _updateMaldaBorrowIndex(address mToken) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market whose borrow index to update|


### _distributeSupplierMalda

Notify reward distributor for supplier update


```solidity
function _distributeSupplierMalda(address mToken, address supplier) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market in which the supplier is interacting|
|`supplier`|`address`|The address of the supplier to distribute MALDA to|


### _distributeBorrowerMalda

Notify reward distributor for borrower update

*Borrowers will not begin to accrue until after the first interaction with the protocol.*


```solidity
function _distributeBorrowerMalda(address mToken, address borrower) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market in which the borrower is interacting|
|`borrower`|`address`|The address of the borrower to distribute MALDA to|


### _claim


```solidity
function _claim(address[] memory holders, address[] memory mTokens, bool borrowers, bool suppliers) private;
```

### _isDeprecated


```solidity
function _isDeprecated(address mToken) private view returns (bool);
```

