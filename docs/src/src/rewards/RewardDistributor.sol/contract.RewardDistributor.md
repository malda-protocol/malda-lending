# RewardDistributor
[Git Source](https://github.com/malda-protocol/malda-lending/blob/ae9b756ce0322e339daafd68cf97592f5de2033d/src\rewards\RewardDistributor.sol)

**Inherits:**
[IRewardDistributor](/src\interfaces\IRewardDistributor.sol\interface.IRewardDistributor.md), [ExponentialNoError](/src\utils\ExponentialNoError.sol\abstract.ExponentialNoError.md), Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable


## State Variables
### REWARD_INITIAL_INDEX

```solidity
uint224 public constant REWARD_INITIAL_INDEX = 1e36;
```


### operator
The operator that rewards are distributed to


```solidity
address public operator;
```


### rewardMarketState
The Reward state for each reward token for each market


```solidity
mapping(address => mapping(address => IRewardDistributorData.RewardMarketState)) public rewardMarketState;
```


### rewardAccountState
The Reward state for each reward token for each account


```solidity
mapping(address => mapping(address => IRewardDistributorData.RewardAccountState)) public rewardAccountState;
```


### rewardTokens
Added reward tokens


```solidity
address[] public rewardTokens;
```


### isRewardToken
Flag to check if reward token added before


```solidity
mapping(address => bool) public isRewardToken;
```


## Functions
### onlyOperator


```solidity
modifier onlyOperator();
```

### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### claim


```solidity
function claim(address[] memory holders) public override nonReentrant;
```

### getBlockTimestamp

Get block timestamp


```solidity
function getBlockTimestamp() public view override returns (uint32);
```

### getRewardTokens

Added reward tokens


```solidity
function getRewardTokens() public view override returns (address[] memory);
```

### initialize


```solidity
function initialize(address _owner) public initializer;
```

### setOperator


```solidity
function setOperator(address _operator) external onlyOwner;
```

### whitelistToken


```solidity
function whitelistToken(address rewardToken_) public onlyOwner;
```

### updateRewardSpeeds


```solidity
function updateRewardSpeeds(
    address rewardToken_,
    address[] memory mTokens,
    uint256[] memory supplySpeeds,
    uint256[] memory borrowSpeeds
) public onlyOwner;
```

### grantReward


```solidity
function grantReward(address token, address user, uint256 amount) public onlyOwner;
```

### notifySupplyIndex

Notifies supply index


```solidity
function notifySupplyIndex(address mToken) external override onlyOperator;
```

### notifyBorrowIndex

Notifies borrow index


```solidity
function notifyBorrowIndex(address mToken) external override onlyOperator;
```

### notifySupplier

Notifies supplier


```solidity
function notifySupplier(address mToken, address supplier) external override onlyOperator;
```

### notifyBorrower

Notifies borrower


```solidity
function notifyBorrower(address mToken, address borrower) external override onlyOperator;
```

### _updateRewardSpeed


```solidity
function _updateRewardSpeed(address rewardToken, address mToken, uint256 supplySpeed, uint256 borrowSpeed) private;
```

### _notifySupplyIndex


```solidity
function _notifySupplyIndex(address rewardToken, address mToken) private;
```

### _notifyBorrowIndex


```solidity
function _notifyBorrowIndex(address rewardToken, address mToken) private;
```

### _notifySupplier


```solidity
function _notifySupplier(address rewardToken, address mToken, address supplier) private;
```

### _notifyBorrower


```solidity
function _notifyBorrower(address rewardToken, address mToken, address borrower) private;
```

### _claim


```solidity
function _claim(address rewardToken, address[] memory holders) internal;
```

### _grantReward


```solidity
function _grantReward(address token, address user, uint256 amount) internal returns (uint256);
```

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

