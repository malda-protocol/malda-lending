# IRewardDistributorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/aa475cf1d928c29ffb1040de375822affeac4243/src/interfaces/IRewardDistributor.sol)

**Title:**
IRewardDistributorData

**Author:**
Merge Layers Inc.

Storage structs for reward distributor


## Structs
### RewardMarketState

```solidity
struct RewardMarketState {
    /// @notice The supply speed for each market
    uint256 supplySpeed;
    /// @notice The supply index for each market
    uint224 supplyIndex;
    /// @notice The last block timestamp that Reward accrued for supply
    uint32 supplyBlock;
    /// @notice The borrow speed for each market
    uint256 borrowSpeed;
    /// @notice The borrow index for each market
    uint224 borrowIndex;
    /// @notice The last block timestamp that Reward accrued for borrow
    uint32 borrowBlock;
}
```

### RewardAccountState

```solidity
struct RewardAccountState {
    /// @notice The supply index for each market as of the last time the account accrued Reward
    mapping(address => uint256) supplierIndex;
    /// @notice The borrow index for each market as of the last time the account accrued Reward
    mapping(address => uint256) borrowerIndex;
    /// @notice Accrued Reward but not yet transferred
    uint256 rewardAccrued;
}
```

