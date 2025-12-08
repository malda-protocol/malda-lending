# RewardDistributor
[Git Source](https://github.com/malda-protocol/malda-lending/blob/177617a42b7e8d8762d299e2b6c84a3ba81f2fc4/src/rewards/RewardDistributor.sol)

**Inherits:**
[IRewardDistributor](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/interfaces/IRewardDistributor.sol/interface.IRewardDistributor.md), [ExponentialNoError](/Users/igorroncevic/Work/malda/malda-lending/docs/src/src/utils/ExponentialNoError.sol/abstract.ExponentialNoError.md), Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable

**Author:**
Malda Protocol

Distributes reward tokens to suppliers and borrowers across markets.


## State Variables
### REWARD_INITIAL_INDEX
Initial index used when starting accruals


```solidity
uint224 public constant REWARD_INITIAL_INDEX = 1e36
```


### operator
The operator that rewards are distributed to


```solidity
address public operator
```


### rewardMarketState
The Reward state for each reward token for each market


```solidity
mapping(address rewardToken => mapping(address mToken => IRewardDistributorData.RewardMarketState marketState))
    public rewardMarketState
```


### rewardAccountState
The Reward state for each reward token for each account


```solidity
mapping(
    address rewardToken => mapping(address account => IRewardDistributorData.RewardAccountState accountState)
) public rewardAccountState
```


### rewardTokens
Added reward tokens


```solidity
address[] public rewardTokens
```


### isRewardToken
Flag to check if reward token added before


```solidity
mapping(address rewardToken => bool status) public isRewardToken
```


## Functions
### onlyOperator


```solidity
modifier onlyOperator() ;
```

### constructor

Disable initializers for the implementation

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor() ;
```

### setOperator

Sets the operator allowed to notify indices


```solidity
function setOperator(address _operator) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_operator`|`address`|Operator address|


### notifySupplyIndex

Updates supply indices for all reward tokens on a market


```solidity
function notifySupplyIndex(address mToken) external override onlyOperator;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|


### notifyBorrowIndex

Updates borrow indices for all reward tokens on a market


```solidity
function notifyBorrowIndex(address mToken) external override onlyOperator;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|


### notifySupplier

Accrues supplier rewards for all reward tokens on a market


```solidity
function notifySupplier(address mToken, address supplier) external override onlyOperator;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|
|`supplier`|`address`|Supplier address|


### notifyBorrower

Accrues borrower rewards for all reward tokens on a market


```solidity
function notifyBorrower(address mToken, address borrower) external override onlyOperator;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`mToken`|`address`|Market address|
|`borrower`|`address`|Borrower address|


### initialize

Initializes the upgradeable contract


```solidity
function initialize(address _owner) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Owner address|


### claim

Claims rewards for a list of holders across all reward tokens


```solidity
function claim(address[] memory holders) public override nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holders`|`address[]`|Account list to claim for|


### whitelistToken

Whitelists a new reward token


```solidity
function whitelistToken(address rewardToken_) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken_`|`address`|Reward token address|


### updateRewardSpeeds

Updates reward speeds for multiple markets


```solidity
function updateRewardSpeeds(
    address rewardToken_,
    address[] memory mTokens,
    uint256[] memory supplySpeeds,
    uint256[] memory borrowSpeeds
) public onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken_`|`address`|Reward token address|
|`mTokens`|`address[]`|Market addresses|
|`supplySpeeds`|`uint256[]`|Supply speeds per market|
|`borrowSpeeds`|`uint256[]`|Borrow speeds per market|


### getBlockTimestamp

Get block timestamp


```solidity
function getBlockTimestamp() public view override returns (uint32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint32`|timestamp Current block timestamp|


### getRewardTokens

Added reward tokens


```solidity
function getRewardTokens() public view override returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|rewardTokens Array of reward token addresses|


### _claim

Claims rewards for holders for a given token


```solidity
function _claim(address rewardToken, address[] memory holders) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`holders`|`address[]`|Holder list|


### _grantReward

Transfers accrued rewards to a user


```solidity
function _grantReward(address token, address user, uint256 amount) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Reward token|
|`user`|`address`|Recipient address|
|`amount`|`uint256`|Amount to grant|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Remaining amount (if transfer not fully executed)|


### _updateRewardSpeed

Updates supply/borrow speed and indexes for a market


```solidity
function _updateRewardSpeed(address rewardToken, address mToken, uint256 supplySpeed, uint256 borrowSpeed) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market address|
|`supplySpeed`|`uint256`|New supply speed|
|`borrowSpeed`|`uint256`|New borrow speed|


### _notifySupplyIndex

Updates supply index for a reward token/market pair


```solidity
function _notifySupplyIndex(address rewardToken, address mToken) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market address|


### _notifyBorrowIndex

Updates borrow index for a reward token/market pair


```solidity
function _notifyBorrowIndex(address rewardToken, address mToken) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market address|


### _notifySupplier

Accrues supplier rewards for a market


```solidity
function _notifySupplier(address rewardToken, address mToken, address supplier) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market address|
|`supplier`|`address`|Supplier address|


### _notifyBorrower

Accrues borrower rewards for a market


```solidity
function _notifyBorrower(address rewardToken, address mToken, address borrower) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|Reward token address|
|`mToken`|`address`|Market address|
|`borrower`|`address`|Borrower address|


## Errors
### RewardDistributor_OnlyOperator

```solidity
error RewardDistributor_OnlyOperator();
```

### RewardDistributor_TransferFailed

```solidity
error RewardDistributor_TransferFailed();
```

### RewardDistributor_RewardNotValid

```solidity
error RewardDistributor_RewardNotValid();
```

### RewardDistributor_AddressNotValid

```solidity
error RewardDistributor_AddressNotValid();
```

### RewardDistributor_AddressAlreadyRegistered

```solidity
error RewardDistributor_AddressAlreadyRegistered();
```

### RewardDistributor_SupplySpeedArrayLengthMismatch

```solidity
error RewardDistributor_SupplySpeedArrayLengthMismatch();
```

### RewardDistributor_BorrowSpeedArrayLengthMismatch

```solidity
error RewardDistributor_BorrowSpeedArrayLengthMismatch();
```

