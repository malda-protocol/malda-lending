# Operator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/Operator/Operator.sol)

**Inherits:**
[OperatorStorage](/src/Operator/OperatorStorage.sol/abstract.OperatorStorage.md), [ImTokenOperationTypes](/src/interfaces/ImToken.sol/interface.ImTokenOperationTypes.md), OwnableUpgradeable, [HypernativeFirewallProtected](/src/libraries/HypernativeFirewallProtected.sol/abstract.HypernativeFirewallProtected.md)

**Title:**
Operator core controller

**Author:**
Merge Layers Inc.

Access-controlled operator logic for mTokens


## Functions
### onlyAllowedUser

Modifier to restrict access to allowed users only


```solidity
modifier onlyAllowedUser(address user) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address to check|


### ifNotBlacklisted

Modifier to check if user is not blacklisted


```solidity
modifier ifNotBlacklisted(address user) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address to check|


### constructor

Disables initializers for implementation contract

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### initFirewall

Initializes the firewall


```solidity
function initFirewall(address _firewall) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_firewall`|`address`|The firewall address|


### setBlacklister

Sets the blacklist operator


```solidity
function setBlacklister(address _blacklister) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_blacklister`|`address`|The blacklist operator address|


### setBorrowSizeMin

Sets min borrow size per market


```solidity
function setBorrowSizeMin(address[] calldata mTokens, uint256[] calldata amounts) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|The market address|
|`amounts`|`uint256[]`|The new size|


### setWhitelistedUser

Sets user whitelist status


```solidity
function setWhitelistedUser(address user, bool state) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address|
|`state`|`bool`|The new state|


### setWhitelistStatus

Sets the whitelist status


```solidity
function setWhitelistStatus(bool status) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`status`|`bool`|The new status|


### setRolesOperator

Sets a new Operator for the market


```solidity
function setRolesOperator(address _roles) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_roles`|`address`|The new operator address|


### setPriceOracle

Sets a new price oracle

Admin function to set a new price oracle


```solidity
function setPriceOracle(address newOracle) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newOracle`|`address`|Address of the new oracle|


### setCloseFactor

Sets the closeFactor used when liquidating borrows

Admin function to set closeFactor


```solidity
function setCloseFactor(uint256 newCloseFactorMantissa) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCloseFactorMantissa`|`uint256`|New close factor, scaled by 1e18|


### setCollateralFactor

Sets the collateralFactor for a market

Admin function to set per-market collateralFactor


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

Admin function to set liquidationIncentive


```solidity
function setLiquidationIncentive(address market, uint256 newLiquidationIncentiveMantissa) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`market`|`address`|Market address|
|`newLiquidationIncentiveMantissa`|`uint256`|New liquidationIncentive scaled by 1e18|


### supportMarket

Add the market to the markets mapping and set it as listed

Admin function to set isListed and add support for the market


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

when 0, it means there's no limit


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

Verifies outflow volume limit


```solidity
function checkOutflowVolumeLimit(uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to check|


### setMarketBorrowCaps

Set borrow caps for given mToken markets.

Borrowing that brings total borrows to or above borrow cap will revert.
A value of 0 corresponds to unlimited borrowing.


```solidity
function setMarketBorrowCaps(address[] calldata mTokens, uint256[] calldata newBorrowCaps)
    external
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|The addresses of the markets (tokens) to change the borrow caps for|
|`newBorrowCaps`|`uint256[]`|The new borrow cap values in underlying to be set.|


### setMarketSupplyCaps

Set supply caps for the given mToken markets.

Supplying that brings total supply to or above supply cap will revert.
A value of 0 corresponds to unlimited supplying.


```solidity
function setMarketSupplyCaps(address[] calldata mTokens, uint256[] calldata newSupplyCaps)
    external
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|The addresses of the markets (tokens) to change the supply caps for|
|`newSupplyCaps`|`uint256[]`|The new supply cap values in underlying to be set.|


### setPaused

Set pause for a specific operation


```solidity
function setPaused(address mToken, ImTokenOperationTypes.OperationType _type, bool state)
    external
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market token address|
|`_type`|`ImTokenOperationTypes.OperationType`|The pause operation type|
|`state`|`bool`|The pause operation status|


### initialize

Initialize the contract


```solidity
function initialize(address _rolesOperator, address _blacklistOperator, address _admin) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_rolesOperator`|`address`|The roles operator address|
|`_blacklistOperator`|`address`|The blacklist operator address|
|`_admin`|`address`|The admin address|


### enterMarkets

Add assets to be included in account liquidity calculation


```solidity
function enterMarkets(address[] calldata _mTokens)
    external
    override
    onlyAllowedUser(msg.sender)
    onlyFirewallApproved;
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

Sender must not have an outstanding borrow balance in the asset,
and must not be providing necessary collateral for an outstanding borrow.


```solidity
function exitMarket(address _mToken) external override onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|The address of the asset to be removed|


### beforeMTokenTransfer

Checks if the account should be allowed to transfer tokens in the given market


```solidity
function beforeMTokenTransfer(address mToken, address src, address dst, uint256 transferTokens)
    external
    override
    ifNotBlacklisted(src)
    ifNotBlacklisted(dst)
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the transfer against|
|`src`|`address`|The account which sources the tokens|
|`dst`|`address`|The account which receives the tokens|
|`transferTokens`|`uint256`|The number of mTokens to transfer|


### beforeMTokenBorrow

Checks if the account should be allowed to borrow the underlying asset of the given market


```solidity
function beforeMTokenBorrow(address mToken, address borrower, uint256 borrowAmount)
    external
    override
    onlyAllowedUser(borrower)
    ifNotBlacklisted(borrower)
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the borrow against|
|`borrower`|`address`|The account which would borrow the asset|
|`borrowAmount`|`uint256`|The amount of underlying the account would borrow|


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

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|paused True if paused|


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
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`mTokens`|`address[]`|List of markets|


### isDeprecated

Returns true if the given mToken market has been deprecated

All borrows in a deprecated mToken market can be immediately liquidated


```solidity
function isDeprecated(address mToken) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to check if deprecated|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|deprecated True if deprecated|


### isMarketListed

Returns true/false


```solidity
function isMarketListed(address mToken) external view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|listed True if market is listed|


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
|`<none>`|`uint256`|liquidity Account liquidity in excess of collateral requirements|
|`<none>`|`uint256`|shortfall Account shortfall below collateral requirements|


### beforeMTokenMint

Checks if the account should be allowed to mint tokens in the given market


```solidity
function beforeMTokenMint(address mToken, address minter, address receiver)
    external
    view
    override
    onlyAllowedUser(minter)
    ifNotBlacklisted(minter)
    ifNotBlacklisted(receiver)
    onlyFirewallApproved
    onlyAllowedUser(minter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the mint against|
|`minter`|`address`|The account which would supplies the assets|
|`receiver`|`address`|The account which would get the minted tokens|


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
    view
    override
    onlyAllowedUser(redeemer)
    ifNotBlacklisted(redeemer)
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the redeem against|
|`redeemer`|`address`|The account which would redeem the tokens|
|`redeemTokens`|`uint256`|The number of mTokens to exchange for the underlying asset in the market|


### beforeMTokenRepay

Checks if the account should be allowed to repay a borrow in the given market


```solidity
function beforeMTokenRepay(address mToken, address borrower)
    external
    view
    onlyAllowedUser(borrower)
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the repay against|
|`borrower`|`address`|The account which would borrowed the asset|


### beforeMTokenLiquidate

Checks if the liquidation should be allowed to occur


```solidity
function beforeMTokenLiquidate(
    address mTokenBorrowed,
    address mTokenCollateral,
    address borrower,
    uint256 repayAmount
) external view override onlyFirewallApproved;
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
function beforeMTokenSeize(address mTokenCollateral, address mTokenBorrowed, address liquidator)
    external
    view
    override
    ifNotBlacklisted(liquidator)
    onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mTokenCollateral`|`address`|Asset which was used as collateral and will be seized|
|`mTokenBorrowed`|`address`|Asset which was borrowed by the borrower|
|`liquidator`|`address`|The address repaying the borrow and seizing the collateral|


### getUSDValueForAllMarkets

Returns USD value for all markets


```solidity
function getUSDValueForAllMarkets() external view returns (uint256 sum);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sum`|`uint256`|The total USD value of all markets|


### beforeRebalancing

Checks if the account should be allowed to rebalance tokens


```solidity
function beforeRebalancing(address mToken) external view override onlyFirewallApproved;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to verify the transfer against|


### firewallRegister

Registers an account with the firewall


```solidity
function firewallRegister(address _account) public override(HypernativeFirewallProtected);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|Account to register|


### _convertMarketAmountToUSDValue

Converts a market amount to USD value


```solidity
function _convertMarketAmountToUSDValue(uint256 amount, address mToken) internal view returns (uint256 usdValue);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount to convert|
|`mToken`|`address`|The market to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`usdValue`|`uint256`|The USD value of the amount|


### _activateMarket

Activates a market for a borrower


```solidity
function _activateMarket(address _mToken, address borrower) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_mToken`|`address`|The market to activate|
|`borrower`|`address`|The borrower to activate the market for|


### _beforeRedeem

Checks if the redeemer is in the market and has sufficient liquidity


```solidity
function _beforeRedeem(address mToken, address redeemer, uint256 redeemTokens) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market to check|
|`redeemer`|`address`|The redeemer to check|
|`redeemTokens`|`uint256`|The number of tokens to redeem|


### _getHypotheticalAccountLiquidity

Gets the hypothetical account liquidity


```solidity
function _getHypotheticalAccountLiquidity(
    address account,
    address mTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount
) private view returns (uint256, uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to get the liquidity for|
|`mTokenModify`|`address`|The market to modify|
|`redeemTokens`|`uint256`|The number of tokens to redeem|
|`borrowAmount`|`uint256`|The amount of underlying to borrow|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|liquidity The liquidity in excess of collateral requirements|
|`<none>`|`uint256`|shortfall The shortfall below collateral requirements|


### _isDeprecated

Checks if a market is deprecated


```solidity
function _isDeprecated(address mToken) private view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|The market address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|deprecated True if the market is deprecated|


