// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";

import {AuthLibrary} from "script/utils/AuthLibrary.sol";
import {DeployAcrossBridge} from "script/v2/deploy/single/rebalancer/DeployAcrossBridge.s.sol";
import {DeployBatchSubmitter} from "script/v2/deploy/single/generic/DeployBatchSubmitter.s.sol";
import {DeployBlacklister} from "script/v2/deploy/single/generic/DeployBlacklister.s.sol";
import {DeployEverclearBridge} from "script/v2/deploy/single/rebalancer/DeployEverclearBridge.s.sol";
import {DeployExtensionMarket} from "script/v2/deploy/single/markets/DeployExtensionMarket.s.sol";
import {DeployGasHelper} from "script/v2/deploy/single/generic/DeployGasHelper.s.sol";
import {DeployHostMarket} from "script/v2/deploy/single/markets/DeployHostMarket.s.sol";
import {DeployJumpRateModelV4} from "script/v2/deploy/single/interest/DeployJumpRateModelV4.s.sol";
import {DeployMixedPriceOracleV4} from "script/v2/deploy/single/oracles/DeployMixedPriceOracleV4.s.sol";
import {DeployOperator} from "script/v2/deploy/single/markets/DeployOperator.s.sol";
import {DeployPauser} from "script/v2/deploy/single/generic/DeployPauser.s.sol";
import {DeployRbac} from "script/v2/deploy/single/generic/DeployRbac.s.sol";
import {DeployRebalancer} from "script/v2/deploy/single/rebalancer/DeployRebalancer.s.sol";
import {DeployRewardDistributor} from "script/v2/deploy/single/rewards/DeployRewardDistributor.s.sol";
import {DeployTimelockController} from "script/v2/deploy/single/generic/DeployTimelockController.s.sol";
import {DeployZkVerifier} from "script/v2/deploy/single/generic/DeployZkVerifier.s.sol";

import {SetBorrowCap} from "script/v2/functions/SetBorrowCap.s.sol";
import {SetBorrowRateMaxMantissa} from "script/v2/functions/SetBorrowRateMaxMantissa.s.sol";
import {SetCloseFactor} from "script/v2/functions/SetCloseFactor.s.sol";
import {SetCollateralFactor} from "script/v2/functions/SetCollateralFactor.s.sol";
import {SetGasHelper} from "script/v2/functions/SetGasHelper.s.sol";
import {SetLiquidationBonus} from "script/v2/functions/SetLiquidationBonus.s.sol";
import {SetMinBorrowSize} from "script/v2/functions/SetMinBorrowSize.s.sol";
import {SetOperatorInRewardDistributor} from "script/v2/functions/SetOperatorInRewardDistributor.s.sol";
import {SetPriceFeedOnOracleV4} from "script/v2/functions/SetPriceFeedOnOracleV4.s.sol";
import {SetReserveFactor} from "script/v2/functions/SetReserveFactor.s.sol";
import {SetSupplyCap} from "script/v2/functions/SetSupplyCap.s.sol";
import {SetWhitelistEnabled} from "script/v2/functions/SetWhitelistEnabled.s.sol";
import {SupportMarket} from "script/v2/functions/SupportMarket.s.sol";

import {ConfigSetup} from "script/utils/ConfigSetup.sol";
import {DeployerUtil} from "script/utils/DeployerUtil.sol";
import {JsonReader} from "script/utils/JsonReader.sol";
import {Logger} from "script/utils/Logger.sol";

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";

/// @title DeployNewChain
/// @notice Executes grouped deploy + post-configuration flow with one shared config and output file
contract DeployNewChain is Script, ConfigSetup {
    using DeployerUtil for *;

    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct CoreContracts {
        address roles;
        address blacklister;
        address zkVerifier;
        address batchSubmitter;
        address timelockController;
        address gasHelper;
        address rewardDistributor;
        address oracle;
        address operator;
        address pauser;
        address rebalancer;
        address acrossBridge;
        address everclearBridge;
    }

    struct DeployedContracts {
        CoreContracts core;
        address[] hostMarkets;
        address[] extensionMarkets;
        address[] interestModels;
    }

    struct MarketPostConfiguration {
        bool enabled;
        uint256[] hostAllowedChainIds;
    }

    struct RebalancerPostConfiguration {
        bool enabled;
        uint256[] whitelistDestinationChainIds;
        address[] acrossAllowedTokens;
        address[] everclearAllowedTokens;
    }

    struct ExtensionWhitelistPostConfiguration {
        bool enabled;
        address[] users;
        address[] skipMarkets;
        bool whitelistEnabled;
        bool userStatus;
    }

    struct NewChainDeploymentConfig {
        bool isHostChain;
        string[] hostMarketIds;
        string[] extensionMarketIds;
        MarketPostConfiguration marketPostConfiguration;
        RebalancerPostConfiguration rebalancerPostConfiguration;
        ExtensionWhitelistPostConfiguration extensionWhitelistPostConfiguration;
    }

    ////////////////////////////////////////////////////////////
    //                       Constants                        //
    ////////////////////////////////////////////////////////////

    string internal constant DEFAULT_CONFIG_PATH = "config/deploy/multi/DeployNewChain.config.json";
    string internal constant DEFAULT_OUTPUT_PATH = "config/deploy/multi/DeployNewChain.output.json";

    string internal constant NEW_CHAIN_DEPLOYMENT_NAMESPACE = "newChainDeployment";
    string internal constant OUTPUT_NEW_CHAIN = "deployNewChain";
    string internal constant OUTPUT_DEPLOYED_CONTRACTS = "deployedContracts";
    string internal constant KEY_MARKET_POST_CONFIGURATION = "marketPostConfiguration";
    string internal constant KEY_REBALANCER_POST_CONFIGURATION = "rebalancerPostConfiguration";
    string internal constant KEY_EXTENSION_WHITELIST_POST_CONFIGURATION = "extensionWhitelistPostConfiguration";
    string internal constant PREFIX_HOST_MARKET = "HostMarket_";
    string internal constant PREFIX_EXTENSION_MARKET = "ExtensionMarket_";
    string internal constant PREFIX_INTEREST_MODEL = "JumpRateModelV4_";
    bytes32 internal constant ROLE_REBALANCER_EOA = keccak256(bytes("REBALANCER_EOA"));

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    error InvalidChainId(uint256 chainId);
    error InvalidMarketId();

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    /// @notice Sets default config and output paths for grouped release execution
    constructor() ConfigSetup(DEFAULT_CONFIG_PATH, DEFAULT_OUTPUT_PATH) {}

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Executes grouped release deployment using default config/output paths
    /// @return deployedContracts Aggregated deployed addresses and market lists
    function run() public returns (DeployedContracts memory deployedContracts) {
        return run(DEFAULT_CONFIG_PATH, DEFAULT_OUTPUT_PATH);
    }

    /// @notice Executes grouped release deployment using custom config/output paths
    /// @param configPath_ Shared config path
    /// @param outputPath_ Shared output path
    /// @return deployedContracts Aggregated deployed addresses and market lists
    function run(string memory configPath_, string memory outputPath_)
        public
        returns (DeployedContracts memory deployedContracts)
    {
        // Effects: select config and output files for the current invocation
        setConfigPath(vm, configPath_);
        setOutputPath(vm, outputPath_);

        // Interactions: read config and seed output storage
        string memory configJson = vm.readFile(DeployerUtil.buildAbsolutePath(vm, configPath));
        string memory outputFilePath = DeployerUtil.buildAbsolutePath(vm, outputPath);
        DeployerUtil.seedOutputJsonForDeployment(vm, outputFilePath);

        // Effects: decode orchestration parameters
        NewChainDeploymentConfig memory cfg = _loadNewChainDeploymentConfig(configJson);

        // Interactions: execute deploy phases in deterministic order
        deployedContracts.core = _deployCore(cfg);
        deployedContracts.interestModels = _deployInterestModels(cfg);
        (deployedContracts.hostMarkets, deployedContracts.extensionMarkets) =
            _deployMarkets(cfg, deployedContracts.core, deployedContracts.interestModels);

        // Interactions: execute optional post-configuration phases
        if (cfg.marketPostConfiguration.enabled) {
            _configureMarkets(cfg, deployedContracts);
        }
        // Interactions: execute optional rebalancer post-configuration phases
        if (cfg.rebalancerPostConfiguration.enabled) {
            _configureRebalancer(cfg, deployedContracts);
        }
        // Interactions: execute optional extension whitelist post-configuration phases
        if (cfg.extensionWhitelistPostConfiguration.enabled && deployedContracts.extensionMarkets.length > 0) {
            _configureExtensionWhitelist(cfg, deployedContracts.extensionMarkets);
        }

        // Effects: persist grouped deployment summary
        _writeAggregatedOutput(cfg, deployedContracts, outputFilePath);
        Logger.logOutputPath(vm, outputPath, false);
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Loads grouped deploy configuration from shared config JSON
    /// @param configJson Shared config JSON blob
    /// @return cfg Parsed grouped deployment config
    function _loadNewChainDeploymentConfig(string memory configJson)
        internal
        returns (NewChainDeploymentConfig memory cfg)
    {
        // Effects: read global deployment mode and market identifiers
        cfg.isHostChain =
            JsonReader.readBool(configJson, JsonReader.getPropertyPath(NEW_CHAIN_DEPLOYMENT_NAMESPACE, "isHostChain"));
        cfg.hostMarketIds = JsonReader.readStringArray(
            configJson, JsonReader.getPropertyPath(NEW_CHAIN_DEPLOYMENT_NAMESPACE, "hostMarketIds")
        );
        cfg.extensionMarketIds = JsonReader.readStringArray(
            configJson, JsonReader.getPropertyPath(NEW_CHAIN_DEPLOYMENT_NAMESPACE, "extensionMarketIds")
        );

        // Effects: read market post-configuration options
        cfg.marketPostConfiguration.enabled = JsonReader.readBool(
            configJson,
            JsonReader.getPropertyPath(NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_MARKET_POST_CONFIGURATION, "enabled")
        );
        cfg.marketPostConfiguration.hostAllowedChainIds = JsonReader.readUintArray(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_MARKET_POST_CONFIGURATION, "hostAllowedChainIds"
            )
        );

        // Effects: read rebalancer post-configuration options
        cfg.rebalancerPostConfiguration.enabled = JsonReader.readBool(
            configJson,
            JsonReader.getPropertyPath(NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_REBALANCER_POST_CONFIGURATION, "enabled")
        );
        cfg.rebalancerPostConfiguration.whitelistDestinationChainIds = JsonReader.readUintArray(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_REBALANCER_POST_CONFIGURATION, "whitelistDestinationChainIds"
            )
        );
        cfg.rebalancerPostConfiguration.acrossAllowedTokens = JsonReader.readAddressArray(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_REBALANCER_POST_CONFIGURATION, "acrossAllowedTokens"
            )
        );
        cfg.rebalancerPostConfiguration.everclearAllowedTokens = JsonReader.readAddressArray(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_REBALANCER_POST_CONFIGURATION, "everclearAllowedTokens"
            )
        );

        // Effects: read extension whitelist post-configuration options
        cfg.extensionWhitelistPostConfiguration.enabled = JsonReader.readBool(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_EXTENSION_WHITELIST_POST_CONFIGURATION, "enabled"
            )
        );
        cfg.extensionWhitelistPostConfiguration.users = JsonReader.readAddressArray(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_EXTENSION_WHITELIST_POST_CONFIGURATION, "users"
            )
        );
        cfg.extensionWhitelistPostConfiguration.skipMarkets = JsonReader.readAddressArray(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_EXTENSION_WHITELIST_POST_CONFIGURATION, "skipMarkets"
            )
        );
        cfg.extensionWhitelistPostConfiguration.whitelistEnabled = JsonReader.readBool(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_EXTENSION_WHITELIST_POST_CONFIGURATION, "whitelistEnabled"
            )
        );
        cfg.extensionWhitelistPostConfiguration.userStatus = JsonReader.readBool(
            configJson,
            JsonReader.getPropertyPath(
                NEW_CHAIN_DEPLOYMENT_NAMESPACE, KEY_EXTENSION_WHITELIST_POST_CONFIGURATION, "userStatus"
            )
        );
    }

    /// @notice Deploys core protocol contracts and related role wiring
    /// @param cfg Parsed grouped deployment config
    /// @return core Aggregated addresses for core contracts
    function _deployCore(NewChainDeploymentConfig memory cfg) internal returns (CoreContracts memory core) {
        // Interactions: deploy role management and foundational contracts
        core.roles = new DeployRbac().run("", configPath, outputPath);
        core.blacklister = new DeployBlacklister().withRoles(core.roles).run("", configPath, outputPath);
        core.zkVerifier = new DeployZkVerifier().run("", configPath, outputPath);
        core.batchSubmitter = new DeployBatchSubmitter().withRoles(core.roles).withZkVerifier(core.zkVerifier)
            .run("", configPath, outputPath);
        core.timelockController = new DeployTimelockController().run("", configPath, outputPath);
        core.gasHelper = new DeployGasHelper().run("", configPath, outputPath);

        // Interactions: deploy rebalancer before bridges because AcrossBridge requires rebalancer in constructor config
        core.rebalancer = new DeployRebalancer().withRoles(core.roles).run("", configPath, outputPath);

        // Interactions: deploy bridge adapters using their single-script default namespaces
        core.acrossBridge = new DeployAcrossBridge().withRoles(core.roles).withRebalancer(core.rebalancer)
            .run("", configPath, outputPath);
        core.everclearBridge = new DeployEverclearBridge().withRoles(core.roles).run("", configPath, outputPath);

        // Interactions: grant rebalancer role directly on Roles contract
        vm.startBroadcast();
        _setRole(core.roles, core.rebalancer, ROLE_REBALANCER_EOA, true);
        vm.stopBroadcast();

        // Interactions: deploy host-only contracts and host-mode pauser wiring
        if (cfg.isHostChain) {
            core.rewardDistributor = new DeployRewardDistributor().run("", configPath, outputPath);
            core.oracle = new DeployMixedPriceOracleV4().withRoles(core.roles).run("", configPath, outputPath);
            core.operator = new DeployOperator().withBlacklistOperator(core.blacklister).withOracle(core.oracle)
                .withRewardDistributor(core.rewardDistributor).withRoles(core.roles).run("", configPath, outputPath);

            new SetOperatorInRewardDistributor().withOperator(core.operator)
                .withRewardDistributor(core.rewardDistributor).run("", configPath, outputPath);

            core.pauser =
                new DeployPauser().withRoles(core.roles).withOperator(core.operator).run("", configPath, outputPath);
            return core;
        }

        // Interactions: deploy extension-mode pauser wiring
        core.pauser = new DeployPauser().withRoles(core.roles).run("", configPath, outputPath);
    }

    /// @notice Deploys interest model contracts derived from configured host market identifiers
    /// @param cfg Parsed grouped deployment config
    /// @return interestModels Deployed interest model addresses ordered by `hostMarketIds`
    function _deployInterestModels(NewChainDeploymentConfig memory cfg)
        internal
        returns (address[] memory interestModels)
    {
        // Effects: initialize output array aligned with host market identifiers
        uint256 length = cfg.hostMarketIds.length;
        interestModels = new address[](length);

        // Interactions: deploy one interest model for each host market identifier
        for (uint256 i; i < length; ++i) {
            // Requirements: each market identifier must be non-empty
            require(bytes(cfg.hostMarketIds[i]).length > 0, InvalidMarketId());

            interestModels[i] = new DeployJumpRateModelV4()
                .run(string.concat(PREFIX_INTEREST_MODEL, cfg.hostMarketIds[i]), configPath, outputPath);
        }
    }

    /// @notice Deploys host and extension markets
    /// @param cfg Parsed grouped deployment config
    /// @param core Aggregated core deployment addresses
    /// @param interestModels Deployed interest model addresses
    /// @return hostMarkets Deployed host market addresses
    /// @return extensionMarkets Deployed extension market addresses
    function _deployMarkets(
        NewChainDeploymentConfig memory cfg,
        CoreContracts memory core,
        address[] memory interestModels
    ) internal returns (address[] memory hostMarkets, address[] memory extensionMarkets) {
        // Effects: pre-size market arrays based on configured market identifiers
        uint256 hostMarketsLength = cfg.hostMarketIds.length;
        uint256 extensionMarketsLength = cfg.extensionMarketIds.length;
        hostMarkets = new address[](hostMarketsLength);
        extensionMarkets = new address[](extensionMarketsLength);

        // Interactions: deploy host markets in deterministic order
        for (uint256 i; i < hostMarketsLength; ++i) {
            hostMarkets[i] = _deployHostMarket(cfg, core, interestModels[i], i);
        }

        // Interactions: deploy extension markets in deterministic order
        for (uint256 i; i < extensionMarketsLength; ++i) {
            extensionMarkets[i] = _deployExtensionMarket(cfg, core, i);
        }
    }

    /// @notice Deploys one host market and applies per-market host chain allowlist update
    /// @param cfg Parsed grouped deployment config
    /// @param core Aggregated core deployment addresses
    /// @param interestModel Interest model assigned to this host market
    /// @param index Index in `hostMarketIds`
    /// @return hostMarket Deployed host market address
    function _deployHostMarket(
        NewChainDeploymentConfig memory cfg,
        CoreContracts memory core,
        address interestModel,
        uint256 index
    ) internal returns (address hostMarket) {
        string memory _hostMarketNamespace = _buildHostMarketNamespace(cfg.hostMarketIds[index]);

        // Requirements: host market identifier must be present
        require(bytes(cfg.hostMarketIds[index]).length > 0, InvalidMarketId());

        // Interactions: deploy host market with dependency overrides
        hostMarket = new DeployHostMarket().withOperator(core.operator).withZkVerifier(core.zkVerifier)
            .withRoles(core.roles).withInterestModel(interestModel).run(_hostMarketNamespace, configPath, outputPath);

        string memory _setGasHelperNamespace = _buildMarketStepNamespace("setGasHelper", _hostMarketNamespace);

        // Interactions: apply gas helper wiring for this host market
        new SetGasHelper().withMarket(hostMarket).withGasHelper(core.gasHelper)
            .run(_setGasHelperNamespace, configPath, outputPath);

        // Interactions: update host chain allowlist directly on deployed host market
        if (cfg.marketPostConfiguration.hostAllowedChainIds.length > 0) {
            vm.startBroadcast();
            for (uint256 i; i < cfg.marketPostConfiguration.hostAllowedChainIds.length; ++i) {
                // Requirements: configured chainId should fit uint32 for mToken host API
                uint256 chainId = cfg.marketPostConfiguration.hostAllowedChainIds[i];
                require(chainId == uint256(uint32(chainId)), InvalidChainId(chainId));
                mErc20Host(payable(hostMarket)).updateAllowedChain(uint32(chainId), true);
            }
            vm.stopBroadcast();
        }
    }

    /// @notice Deploys one extension market by configured extension market identifier
    /// @param cfg Parsed grouped deployment config
    /// @param core Aggregated core deployment addresses
    /// @param index Index in `extensionMarketIds`
    /// @return extensionMarket Deployed extension market address
    function _deployExtensionMarket(NewChainDeploymentConfig memory cfg, CoreContracts memory core, uint256 index)
        internal
        returns (address extensionMarket)
    {
        // Requirements: extension market identifier must be present
        require(bytes(cfg.extensionMarketIds[index]).length > 0, InvalidMarketId());

        // Interactions: deploy extension market with dependency overrides
        extensionMarket = new DeployExtensionMarket().withBlacklister(core.blacklister).withZkVerifier(core.zkVerifier)
            .withRoles(core.roles)
            .run(string.concat(PREFIX_EXTENSION_MARKET, cfg.extensionMarketIds[index]), configPath, outputPath);
    }

    /// @notice Executes market-level post-configuration calls
    /// @param cfg Parsed grouped deployment config
    /// @param deployedContracts Aggregated deployed contracts
    function _configureMarkets(NewChainDeploymentConfig memory cfg, DeployedContracts memory deployedContracts)
        internal
    {
        // Interactions: execute global operator-level market configuration calls
        if (deployedContracts.core.operator != address(0)) {
            new SetWhitelistEnabled().withOperator(deployedContracts.core.operator).run("", configPath, outputPath);
            new SetCloseFactor().withOperator(deployedContracts.core.operator).run("", configPath, outputPath);
        }

        // Interactions: execute global oracle feed update
        if (deployedContracts.core.oracle != address(0)) {
            new SetPriceFeedOnOracleV4().withOracle(deployedContracts.core.oracle).run("", configPath, outputPath);
        }

        // Interactions: execute per-host-market configuration calls
        for (uint256 i; i < deployedContracts.hostMarkets.length; ++i) {
            address market = deployedContracts.hostMarkets[i];
            string memory marketNamespace = _buildHostMarketNamespace(cfg.hostMarketIds[i]);
            string memory _supportMarketNamespace = _buildMarketStepNamespace("supportMarket", marketNamespace);
            string memory _setCollateralFactorNamespace =
                _buildMarketStepNamespace("setCollateralFactor", marketNamespace);
            string memory _setBorrowCapNamespace = _buildMarketStepNamespace("setBorrowCap", marketNamespace);
            string memory _setMinBorrowSizeNamespace = _buildMarketStepNamespace("setMinBorrowSize", marketNamespace);
            string memory _setSupplyCapNamespace = _buildMarketStepNamespace("setSupplyCap", marketNamespace);
            string memory _setLiquidationBonusNamespace =
                _buildMarketStepNamespace("setLiquidationBonus", marketNamespace);
            string memory _setReserveFactorNamespace = _buildMarketStepNamespace("setReserveFactor", marketNamespace);
            string memory _setBorrowRateMaxMantissaNamespace =
                _buildMarketStepNamespace("setBorrowRateMaxMantissa", marketNamespace);

            new SupportMarket().withOperator(deployedContracts.core.operator).withMarket(market)
                .run(_supportMarketNamespace, configPath, outputPath);
            new SetCollateralFactor().withOperator(deployedContracts.core.operator).withMarket(market)
                .run(_setCollateralFactorNamespace, configPath, outputPath);
            new SetBorrowCap().withOperator(deployedContracts.core.operator).withMarket(market)
                .run(_setBorrowCapNamespace, configPath, outputPath);
            new SetMinBorrowSize().withOperator(deployedContracts.core.operator).withMarket(market)
                .run(_setMinBorrowSizeNamespace, configPath, outputPath);
            new SetSupplyCap().withOperator(deployedContracts.core.operator).withMarket(market)
                .run(_setSupplyCapNamespace, configPath, outputPath);
            new SetLiquidationBonus().withOperator(deployedContracts.core.operator).withMarket(market)
                .run(_setLiquidationBonusNamespace, configPath, outputPath);
            new SetReserveFactor().withMarket(market).run(_setReserveFactorNamespace, configPath, outputPath);
            new SetBorrowRateMaxMantissa().withMarket(market)
                .run(_setBorrowRateMaxMantissaNamespace, configPath, outputPath);
        }
    }

    /// @notice Grants or revokes a role when both target addresses are configured
    /// @param rolesContract Roles contract address
    /// @param account Account to grant/revoke
    /// @param role Role identifier
    /// @param status True to grant, false to revoke
    function _setRole(address rolesContract, address account, bytes32 role, bool status) internal {
        // Requirements: skip no-op role updates when inputs are unset
        if (rolesContract == address(0) || account == address(0)) {
            return;
        }

        // Interactions: execute role update through AuthLibrary helper
        AuthLibrary.grantRole(rolesContract, account, role, status);
    }

    /// @notice Executes rebalancer whitelist and allowlist configuration
    /// @param cfg Parsed grouped deployment config
    /// @param deployedContracts Aggregated deployed contracts
    function _configureRebalancer(NewChainDeploymentConfig memory cfg, DeployedContracts memory deployedContracts)
        internal
    {
        // Requirements: skip configuration if rebalancer was not deployed
        address rebalancer = deployedContracts.core.rebalancer;
        if (rebalancer == address(0)) {
            return;
        }

        // Interactions: apply destination and bridge allowlists
        vm.startBroadcast();

        for (uint256 i; i < cfg.rebalancerPostConfiguration.whitelistDestinationChainIds.length; ++i) {
            // Requirements: configured chainId should fit uint32 for rebalancer API
            uint256 chainId = cfg.rebalancerPostConfiguration.whitelistDestinationChainIds[i];
            require(chainId == uint256(uint32(chainId)), InvalidChainId(chainId));

            // Interactions: only whitelist remote destination chains
            uint32 destinationChainId = uint32(chainId);
            if (destinationChainId != uint32(block.chainid)) {
                Rebalancer(rebalancer).setWhitelistedDestination(destinationChainId, true);
            }
        }

        if (deployedContracts.core.acrossBridge != address(0)) {
            Rebalancer(rebalancer).setWhitelistedBridgeStatus(deployedContracts.core.acrossBridge, true);
            if (cfg.rebalancerPostConfiguration.acrossAllowedTokens.length > 0) {
                Rebalancer(rebalancer)
                    .setAllowedTokens(
                        deployedContracts.core.acrossBridge, cfg.rebalancerPostConfiguration.acrossAllowedTokens, true
                    );
            }
        }

        if (deployedContracts.core.everclearBridge != address(0)) {
            Rebalancer(rebalancer).setWhitelistedBridgeStatus(deployedContracts.core.everclearBridge, true);
            if (cfg.rebalancerPostConfiguration.everclearAllowedTokens.length > 0) {
                Rebalancer(rebalancer)
                    .setAllowedTokens(
                        deployedContracts.core.everclearBridge,
                        cfg.rebalancerPostConfiguration.everclearAllowedTokens,
                        true
                    );
            }
        }

        // Effects + Interactions: concatenate host + extension markets and apply allowlist status in one pass
        address[] memory allMarkets =
            new address[](deployedContracts.hostMarkets.length + deployedContracts.extensionMarkets.length);
        for (uint256 i; i < deployedContracts.hostMarkets.length; ++i) {
            allMarkets[i] = deployedContracts.hostMarkets[i];
        }
        for (uint256 i; i < deployedContracts.extensionMarkets.length; ++i) {
            allMarkets[deployedContracts.hostMarkets.length + i] = deployedContracts.extensionMarkets[i];
        }
        if (allMarkets.length > 0) {
            Rebalancer(rebalancer).setAllowList(allMarkets, true);
            Rebalancer(rebalancer).setMarketStatus(allMarkets, true);
        }

        vm.stopBroadcast();
    }

    /// @notice Executes extension-market whitelist updates
    /// @param cfg Parsed grouped deployment config
    /// @param extensionMarkets Deployed extension market addresses
    function _configureExtensionWhitelist(NewChainDeploymentConfig memory cfg, address[] memory extensionMarkets)
        internal
    {
        // Requirements: skip if there are no target users
        if (cfg.extensionWhitelistPostConfiguration.users.length == 0) {
            return;
        }

        // Interactions: update whitelist mode and users on each non-skipped extension market
        vm.startBroadcast();
        for (uint256 i; i < extensionMarkets.length; ++i) {
            address market = extensionMarkets[i];

            // Effects: evaluate whether this market is in skip list
            bool isSkipped;
            for (uint256 j; j < cfg.extensionWhitelistPostConfiguration.skipMarkets.length; ++j) {
                if (cfg.extensionWhitelistPostConfiguration.skipMarkets[j] == market) {
                    isSkipped = true;
                    break;
                }
            }
            if (isSkipped) {
                continue;
            }

            if (cfg.extensionWhitelistPostConfiguration.whitelistEnabled) {
                mTokenGateway(payable(market)).enableWhitelist();
            } else {
                mTokenGateway(payable(market)).disableWhitelist();
            }

            for (uint256 j; j < cfg.extensionWhitelistPostConfiguration.users.length; ++j) {
                mTokenGateway(payable(market))
                    .setWhitelistedUser(
                        cfg.extensionWhitelistPostConfiguration.users[j],
                        cfg.extensionWhitelistPostConfiguration.userStatus
                    );
            }
        }
        vm.stopBroadcast();
    }

    /// @notice Writes aggregated grouped deployment summary into shared output
    /// @param cfg Parsed grouped deployment config
    /// @param deployedContracts Aggregated deployed contracts
    /// @param outputFilePath Absolute output file path
    function _writeAggregatedOutput(
        NewChainDeploymentConfig memory cfg,
        DeployedContracts memory deployedContracts,
        string memory outputFilePath
    ) internal {
        // Effects: serialize grouped deployment summary payload
        string memory json = OUTPUT_NEW_CHAIN;

        vm.serializeBool(json, "isHostChain", cfg.isHostChain);
        vm.serializeAddress(json, "roles", deployedContracts.core.roles);
        vm.serializeAddress(json, "blacklister", deployedContracts.core.blacklister);
        vm.serializeAddress(json, "zkVerifier", deployedContracts.core.zkVerifier);
        vm.serializeAddress(json, "batchSubmitter", deployedContracts.core.batchSubmitter);
        vm.serializeAddress(json, "timelockController", deployedContracts.core.timelockController);
        vm.serializeAddress(json, "gasHelper", deployedContracts.core.gasHelper);
        vm.serializeAddress(json, "rewardDistributor", deployedContracts.core.rewardDistributor);
        vm.serializeAddress(json, "oracle", deployedContracts.core.oracle);
        vm.serializeAddress(json, "operator", deployedContracts.core.operator);
        vm.serializeAddress(json, "pauser", deployedContracts.core.pauser);
        vm.serializeAddress(json, "rebalancer", deployedContracts.core.rebalancer);
        vm.serializeAddress(json, "acrossBridge", deployedContracts.core.acrossBridge);
        vm.serializeAddress(json, "everclearBridge", deployedContracts.core.everclearBridge);
        vm.serializeAddress(json, "hostMarkets", deployedContracts.hostMarkets);
        vm.serializeAddress(json, "extensionMarkets", deployedContracts.extensionMarkets);
        string memory serialized = vm.serializeAddress(json, "interestModels", deployedContracts.interestModels);

        // Interactions: write grouped summary under deployNewChain namespace
        vm.writeJson(
            serialized, outputFilePath, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS)
        );
    }

    ////////////////////////////////////////////////////////////
    //                    View / Pure Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Builds host-market namespace key from market identifier
    /// @param marketId Market identifier from config
    /// @return namespace_ Host-market section key
    function _buildHostMarketNamespace(string memory marketId) internal pure returns (string memory namespace_) {
        // Effects: compose host-market section key
        namespace_ = string.concat(PREFIX_HOST_MARKET, marketId);
    }

    /// @notice Builds step-specific namespace key for a market-specific function call
    /// @param defaultNamespace Default function namespace prefix
    /// @param marketNamespace Market section namespace suffix
    /// @return namespace_ Composed function-call section key
    function _buildMarketStepNamespace(string memory defaultNamespace, string memory marketNamespace)
        internal
        pure
        returns (string memory namespace_)
    {
        // Effects: compose market-scoped function section key
        namespace_ = string.concat(defaultNamespace, "__", marketNamespace);
    }
}
