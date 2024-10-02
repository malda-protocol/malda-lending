# IOperator
[Git Source](https://github.com/malda-protocol/malda-lending/blob/179a048ba4fdf7caff4add1e6a0986ba27ae405c/src\interfaces\IOperator.sol)


## Functions
### admin

Administrator for this contract


```solidity
function admin() external view returns (address);
```

### pendingAdmin

Pending administrator for this contract


```solidity
function pendingAdmin() external view returns (address);
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

### accountAssets

Per-account mapping of "assets you are in", capped by maxAssets


```solidity
function accountAssets(address _user) external view returns (address[] memory mTokens);
```

### allMarkets

A list of all markets


```solidity
function allMarkets() external view returns (address[] memory mTokens);
```

### borroCaps

Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.


```solidity
function borroCaps(address _mToken) external view returns (uint256);
```

### supplyCaps

Supply caps enforced by supplyAllowed for each cToken address. Defaults to zero which corresponds to unlimited supplying.


```solidity
function supplyCaps(address _mToken) external view returns (uint256);
```

### rewardDistributor

Reward Distributor to markets supply and borrow (including protocol token)


```solidity
function rewardDistributor() external view returns (address);
```

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


