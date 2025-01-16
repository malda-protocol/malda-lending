
### Initial Flow

## deployments
1. script/generic/DeployRbac.s.sol
2. script/verifier/DeployZkVerifierImageRegistry.s.sol
3. script/interest/DeployJumpRateModelV2.s.sol
4. script/oracles/DeployChainlinkOracle.s.sol
5. script/rewards/DeployRewardDistributor.s.sol
6. script/markets/DeployOperator.s.sol
7. script/generic/DeployPauser.s.sol
8. script/markets/host/DeployHostMarket.s.sol
9. script/markets/extension/DeployExtensionMarket.s.sol

## configuration
1. script/configuration/SetCollateralFactor.s.sol
2. script/configuration/SetOperatorForRewards.s.sol
3. script/configuration/SetRole.s.sol
3. script/configuration/SupportMarket.s.sol



### New market flow

## deployments
1. script/markets/host/DeployHostMarket.s.sol
2. script/markets/extension/DeployExtensionMarket.s.sol

## configuration
1. script/configuration/SetCollateralFactor.s.sol
3. script/configuration/SuppoertMarket.s.sol