# IRewardDistributor
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/IRewardDistributor.sol)

**Title:**
IRewardDistributor

**Author:**
Merge Layers Inc.

Interface for reward distribution operations


## Functions
### notifySupplyIndex

Updates supply indices for all reward tokens on a market


```solidity
function notifySupplyIndex(address mToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market token|


### notifyBorrowIndex

Updates borrow indices for all reward tokens on a market


```solidity
function notifyBorrowIndex(address mToken) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market token|


### notifySupplier

Notifies supplier


```solidity
function notifySupplier(address mToken, address supplier) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market token|
|`supplier`|`address`|Supplier address|


### notifyBorrower

Notifies borrower


```solidity
function notifyBorrower(address mToken, address borrower) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market token|
|`borrower`|`address`|Borrower address|


### claim

Claim tokens for holders


```solidity
function claim(address[] memory holders) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holders`|`address[]`|The accounts to claim for|


### operator

The operator that rewards are distributed to


```solidity
function operator() external view returns (address operatorAddress);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`operatorAddress`|`address`|Operator address|


### isRewardToken

Flag to check if reward token added before


```solidity
function isRewardToken(address _token) external view returns (bool isRewardTokenAdded);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_token`|`address`|The token to check for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isRewardTokenAdded`|`bool`|True if token is a reward token|


### getRewardTokens

Added reward tokens


```solidity
function getRewardTokens() external view returns (address[] memory rewardTokens);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|Array of reward token addresses|


### getBlockTimestamp

Get block timestamp


```solidity
function getBlockTimestamp() external view returns (uint32 timestamp);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint32`|Current block timestamp|


## Events
### RewardAccrued
Emitted when reward is accrued for a user


```solidity
event RewardAccrued(address indexed rewardToken, address indexed user, uint256 deltaAccrued, uint256 totalAccrued);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`user`|`address`|User address|
|`deltaAccrued`|`uint256`|Newly accrued amount|
|`totalAccrued`|`uint256`|Total accrued amount|

### RewardGranted
Emitted when reward is granted to a user


```solidity
event RewardGranted(address indexed rewardToken, address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`user`|`address`|User address|
|`amount`|`uint256`|Granted amount|

### SupplySpeedUpdated
Emitted when supply speed is updated


```solidity
event SupplySpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 supplySpeed);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market token|
|`supplySpeed`|`uint256`|New supply speed|

### BorrowSpeedUpdated
Emitted when borrow speed is updated


```solidity
event BorrowSpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 borrowSpeed);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market token|
|`borrowSpeed`|`uint256`|New borrow speed|

### OperatorSet
Emitted when operator is updated


```solidity
event OperatorSet(address indexed oldOperator, address indexed newOperator);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldOperator`|`address`|Previous operator|
|`newOperator`|`address`|New operator|

### WhitelistedToken
Emitted when token is whitelisted


```solidity
event WhitelistedToken(address indexed token);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Whitelisted token|

### SupplyIndexNotified
Emitted when supply index is notified


```solidity
event SupplyIndexNotified(address indexed rewardToken, address indexed mToken);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market token|

### BorrowIndexNotified
Emitted when borrow index is notified


```solidity
event BorrowIndexNotified(address indexed rewardToken, address indexed mToken);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market token|

