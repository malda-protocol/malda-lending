# IRewardDistributorData
[Git Source](https://github.com/malda-protocol/malda-lending/blob/157d7bccdcadcb7388d89b00ec47106a82e67e78/src\interfaces\IRewardDistributor.sol)


## Structs
### RewardMarketState

```solidity
struct RewardMarketState {
    uint256 supplySpeed;
    uint224 supplyIndex;
    uint32 supplyBlock;
    uint256 borrowSpeed;
    uint224 borrowIndex;
    uint32 borrowBlock;
}
```

### RewardAccountState

```solidity
struct RewardAccountState {
    mapping(address => uint256) supplierIndex;
    mapping(address => uint256) borrowerIndex;
    uint256 rewardAccrued;
}
```

