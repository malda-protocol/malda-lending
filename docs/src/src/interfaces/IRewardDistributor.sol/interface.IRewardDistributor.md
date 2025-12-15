# IRewardDistributor
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\interfaces\IRewardDistributor.sol)


## Functions
### operator

The operator that rewards are distributed to


```solidity
function operator() external view returns (address);
```

### isRewardToken

Flag to check if reward token added before


```solidity
function isRewardToken(address _token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|the token to check for|


### getRewardTokens

Added reward tokens


```solidity
function getRewardTokens() external view returns (address[] memory);
```

### getBlockTimestamp

Get block timestamp


```solidity
function getBlockTimestamp() external view returns (uint32);
```

### notifySupplyIndex

Notifies supply index


```solidity
function notifySupplyIndex(address mToken) external;
```

### notifyBorrowIndex

Notifies borrow index


```solidity
function notifyBorrowIndex(address mToken) external;
```

### notifySupplier

Notifies supplier


```solidity
function notifySupplier(address mToken, address supplier) external;
```

### notifyBorrower

Notifies borrower


```solidity
function notifyBorrower(address mToken, address borrower) external;
```

### claim

Claim tokens for `holders


```solidity
function claim(address[] memory holders) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holders`|`address[]`|the accounts to claim for|


## Events
### RewardAccrued

```solidity
event RewardAccrued(address indexed rewardToken, address indexed user, uint256 deltaAccrued, uint256 totalAccrued);
```

### RewardGranted

```solidity
event RewardGranted(address indexed rewardToken, address indexed user, uint256 amount);
```

### SupplySpeedUpdated

```solidity
event SupplySpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 supplySpeed);
```

### BorrowSpeedUpdated

```solidity
event BorrowSpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 borrowSpeed);
```

### OperatorSet

```solidity
event OperatorSet(address indexed oldOperator, address indexed newOperator);
```

### WhitelistedToken

```solidity
event WhitelistedToken(address indexed token);
```

### SupplyIndexNotified

```solidity
event SupplyIndexNotified(address indexed rewardToken, address indexed mToken);
```

### BorrowIndexNotified

```solidity
event BorrowIndexNotified(address indexed rewardToken, address indexed mToken);
```

