### Full Deployment

Call this multi script to execute end-to-end deployment:

- `script/v2/deploy/multi/DeployNewChain.s.sol`

Call order inside `DeployNewChain`:

1. `script/v2/deploy/single/generic/DeployRbac.s.sol`
2. `script/v2/deploy/single/generic/DeployBlacklister.s.sol`
3. `script/v2/deploy/single/generic/DeployZkVerifier.s.sol`
4. `script/v2/deploy/single/generic/DeployBatchSubmitter.s.sol`
5. `script/v2/deploy/single/generic/DeployTimelockController.s.sol`
6. `script/v2/deploy/single/generic/DeployGasHelper.s.sol`
7. `script/v2/deploy/single/rebalancer/DeployRebalancer.s.sol`
8. `script/v2/deploy/single/rebalancer/DeployAcrossBridge.s.sol`
9. `script/v2/deploy/single/rebalancer/DeployEverclearBridge.s.sol`
10. `AuthLibrary.grantRole(...)` for `REBALANCER_EOA`
11. Host-chain only:
    `script/v2/deploy/single/rewards/DeployRewardDistributor.s.sol`,
    `script/v2/deploy/single/oracles/DeployMixedPriceOracleV4.s.sol`,
    `script/v2/deploy/single/markets/DeployOperator.s.sol`,
    `script/v2/functions/SetOperatorInRewardDistributor.s.sol`,
    `script/v2/deploy/single/generic/DeployPauser.s.sol`
12. Extension-chain only:
    `script/v2/deploy/single/generic/DeployPauser.s.sol`
13. Per host market:
    `script/v2/deploy/single/interest/DeployJumpRateModelV4.s.sol`,
    `script/v2/deploy/single/markets/DeployHostMarket.s.sol`,
    `script/v2/functions/SetGasHelper.s.sol`
14. Per extension market:
    `script/v2/deploy/single/markets/DeployExtensionMarket.s.sol`
15. If `marketPostConfiguration.enabled`:
    `SetWhitelistEnabled`, `SetCloseFactor`, `SetPriceFeedOnOracleV4`,
    `SupportMarket`, `SetCollateralFactor`, `SetBorrowCap`, `SetMinBorrowSize`,
    `SetSupplyCap`, `SetLiquidationBonus`, `SetReserveFactor`, `SetBorrowRateMaxMantissa`
16. If `rebalancerPostConfiguration.enabled`: rebalancer allowlist/bridge/token configuration
17. If `extensionWhitelistPostConfiguration.enabled`: extension whitelist updates

Post-deploy ownership handoff scripts:

1. `script/v2/deploy/multi/DeployReleaseOwnership.s.sol`
2. Optional: `script/v2/deploy/multi/DeployReleaseOwnershipWithInitialMint.s.sol`


### Deploy New Market

Dedicated v2 market-only deployment script:

1. `script/v2/deploy/multi/DeployNewMarket.s.sol`

Call order in market-only flow:

1. Host market path:
   `DeployJumpRateModelV4` -> `DeployHostMarket` -> `SetGasHelper` -> `Pauser.addPausableMarket` -> `mErc20Host.updateAllowedChain`
2. Extension market path:
   `DeployExtensionMarket` -> `Pauser.addPausableMarket`

Follow-up configuration after market deployment:

1. Mainnet: `script/deployment/mainnet/ConfigureRelease.s.sol`
2. Testnet: `script/deployment/testnet/ConfigureTestnet.s.sol`
