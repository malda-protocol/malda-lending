// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";

import {DeployExtensionMarket} from "script/v2/deploy/single/markets/DeployExtensionMarket.s.sol";
import {DeployHostMarket} from "script/v2/deploy/single/markets/DeployHostMarket.s.sol";
import {DeployJumpRateModelV4} from "script/v2/deploy/single/interest/DeployJumpRateModelV4.s.sol";
import {SetGasHelper} from "script/v2/functions/SetGasHelper.s.sol";

import {ConfigSetup} from "script/utils/ConfigSetup.sol";
import {DeployerUtil} from "script/utils/DeployerUtil.sol";
import {JsonReader} from "script/utils/JsonReader.sol";
import {Logger} from "script/utils/Logger.sol";

import {IPauser} from "src/interfaces/IPauser.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {Pauser} from "src/pauser/Pauser.sol";

/// @title DeployNewMarket
/// @notice Deploys new markets using existing core contracts and appends addresses to shared output
contract DeployNewMarket is Script, ConfigSetup {
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

    struct ExistingDeploymentSummary {
        bool isHostChain;
        CoreContracts core;
        address[] hostMarkets;
        address[] extensionMarkets;
        address[] interestModels;
    }

    struct NewMarketDeploymentConfig {
        bool isHostChain;
        string[] hostMarketIds;
        string[] extensionMarketIds;
        uint256[] hostAllowedChainIds;
    }

    struct DeployedMarkets {
        address[] hostMarkets;
        address[] extensionMarkets;
        address[] interestModels;
    }

    ////////////////////////////////////////////////////////////
    //                       Constants                        //
    ////////////////////////////////////////////////////////////

    string internal constant DEFAULT_CONFIG_PATH = "config/deploy/multi/DeployNewChain.config.json";
    string internal constant DEFAULT_OUTPUT_PATH = "config/deploy/multi/DeployNewChain.output.json";

    string internal constant NEW_MARKET_DEPLOYMENT_NAMESPACE = "newMarketDeployment";
    string internal constant OUTPUT_NEW_CHAIN = "deployNewChain";
    string internal constant OUTPUT_DEPLOYED_CONTRACTS = "deployedContracts";

    string internal constant PREFIX_HOST_MARKET = "HostMarket_";
    string internal constant PREFIX_EXTENSION_MARKET = "ExtensionMarket_";
    string internal constant PREFIX_INTEREST_MODEL = "JumpRateModelV4_";

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    error MissingAggregatedOutput();
    error MissingCoreDependency(string key);
    error InvalidChainId(uint256 chainId);
    error InvalidMarketId();

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    /// @notice Sets default config and output paths for new-market execution
    constructor() ConfigSetup(DEFAULT_CONFIG_PATH, DEFAULT_OUTPUT_PATH) {}

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Executes new-market deployment using default config/output paths
    /// @return deployedMarkets New addresses deployed by this invocation
    function run() public returns (DeployedMarkets memory deployedMarkets) {
        return run(DEFAULT_CONFIG_PATH, DEFAULT_OUTPUT_PATH);
    }

    /// @notice Executes new-market deployment using custom config/output paths
    /// @param configPath_ Shared config path
    /// @param outputPath_ Shared output path
    /// @return deployedMarkets New addresses deployed by this invocation
    function run(string memory configPath_, string memory outputPath_)
        public
        returns (DeployedMarkets memory deployedMarkets)
    {
        // Effects: select config and output files for this invocation
        setConfigPath(vm, configPath_);
        setOutputPath(vm, outputPath_);

        // Interactions: read config/output and ensure output file exists
        string memory configJson = vm.readFile(DeployerUtil.buildAbsolutePath(vm, configPath));
        string memory outputFilePath = DeployerUtil.buildAbsolutePath(vm, outputPath);
        DeployerUtil.seedOutputJsonForDeployment(vm, outputFilePath);
        string memory outputJson = vm.readFile(outputFilePath);

        // Effects: decode deployment parameters and resolve existing shared deployment
        NewMarketDeploymentConfig memory cfg = _loadNewMarketDeploymentConfig(configJson);
        ExistingDeploymentSummary memory existing = _loadExistingDeploymentSummary(outputJson);
        _validateCoreDependencies(cfg, existing.core);

        // Interactions: deploy only new market artifacts for current chain mode
        deployedMarkets.interestModels = _deployInterestModels(cfg);
        (deployedMarkets.hostMarkets, deployedMarkets.extensionMarkets) =
            _deployMarkets(cfg, existing.core, deployedMarkets.interestModels);

        // Effects: append new addresses to shared aggregated output
        existing.hostMarkets = _concat(existing.hostMarkets, deployedMarkets.hostMarkets);
        existing.extensionMarkets = _concat(existing.extensionMarkets, deployedMarkets.extensionMarkets);
        existing.interestModels = _concat(existing.interestModels, deployedMarkets.interestModels);
        existing.isHostChain = cfg.isHostChain;
        _writeAggregatedOutput(existing, outputFilePath);

        Logger.logOutputPath(vm, outputPath, false);
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Loads new-market config from shared config JSON
    /// @param configJson Shared config JSON blob
    /// @return cfg Parsed new-market deployment config
    function _loadNewMarketDeploymentConfig(string memory configJson)
        internal
        returns (NewMarketDeploymentConfig memory cfg)
    {
        // Effects: decode market deployment parameters
        cfg.isHostChain =
            JsonReader.readBool(configJson, JsonReader.getPropertyPath(NEW_MARKET_DEPLOYMENT_NAMESPACE, "isHostChain"));
        cfg.hostMarketIds = JsonReader.readStringArray(
            configJson, JsonReader.getPropertyPath(NEW_MARKET_DEPLOYMENT_NAMESPACE, "hostMarketIds")
        );
        cfg.extensionMarketIds = JsonReader.readStringArray(
            configJson, JsonReader.getPropertyPath(NEW_MARKET_DEPLOYMENT_NAMESPACE, "extensionMarketIds")
        );
        cfg.hostAllowedChainIds = JsonReader.readUintArray(
            configJson, JsonReader.getPropertyPath(NEW_MARKET_DEPLOYMENT_NAMESPACE, "hostAllowedChainIds")
        );
    }

    /// @notice Loads existing aggregated deployment summary from shared output
    /// @param outputJson Shared output JSON blob
    /// @return summary Existing deployed addresses and arrays
    function _loadExistingDeploymentSummary(string memory outputJson)
        internal
        returns (ExistingDeploymentSummary memory summary)
    {
        // Requirements: shared output must already contain new-chain aggregated summary
        require(
            vm.keyExistsJson(outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS)),
            MissingAggregatedOutput()
        );

        // Effects: decode persisted deployment summary
        summary.isHostChain = JsonReader.readBool(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "isHostChain")
        );
        summary.core.roles = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "roles")
        );
        summary.core.blacklister = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "blacklister")
        );
        summary.core.zkVerifier = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "zkVerifier")
        );
        summary.core.batchSubmitter = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "batchSubmitter")
        );
        summary.core.timelockController = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "timelockController")
        );
        summary.core.gasHelper = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "gasHelper")
        );
        summary.core.rewardDistributor = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "rewardDistributor")
        );
        summary.core.oracle = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "oracle")
        );
        summary.core.operator = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "operator")
        );
        summary.core.pauser = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "pauser")
        );
        summary.core.rebalancer = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "rebalancer")
        );
        summary.core.acrossBridge = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "acrossBridge")
        );
        summary.core.everclearBridge = JsonReader.readAddress(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "everclearBridge")
        );
        summary.hostMarkets = JsonReader.readAddressArray(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "hostMarkets")
        );
        summary.extensionMarkets = JsonReader.readAddressArray(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "extensionMarkets")
        );
        summary.interestModels = JsonReader.readAddressArray(
            outputJson, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS, "interestModels")
        );
    }

    /// @notice Validates that required core dependencies are present for target chain mode
    /// @param cfg Parsed new-market deployment config
    /// @param core Existing core contract addresses
    function _validateCoreDependencies(NewMarketDeploymentConfig memory cfg, CoreContracts memory core) internal {
        // Requirements: shared dependencies must be available
        require(core.roles != address(0), MissingCoreDependency("roles"));
        require(core.zkVerifier != address(0), MissingCoreDependency("zkVerifier"));
        require(core.pauser != address(0), MissingCoreDependency("pauser"));

        // Requirements: host-chain market deployment requires host-only dependencies
        if (cfg.isHostChain) {
            require(core.operator != address(0), MissingCoreDependency("operator"));
            require(core.gasHelper != address(0), MissingCoreDependency("gasHelper"));
            return;
        }

        // Requirements: extension-chain market deployment requires extension dependencies
        require(core.blacklister != address(0), MissingCoreDependency("blacklister"));
    }

    /// @notice Deploys interest models for configured host market identifiers
    /// @param cfg Parsed new-market deployment config
    /// @return interestModels Deployed interest model addresses ordered by host market ids
    function _deployInterestModels(NewMarketDeploymentConfig memory cfg)
        internal
        returns (address[] memory interestModels)
    {
        // Effects: extension-chain flow does not deploy interest models
        if (!cfg.isHostChain) {
            return new address[](0);
        }

        // Effects: initialize output array aligned with host market identifiers
        uint256 length = cfg.hostMarketIds.length;
        interestModels = new address[](length);

        // Interactions: deploy one interest model per host market identifier
        for (uint256 i; i < length; ++i) {
            require(bytes(cfg.hostMarketIds[i]).length > 0, InvalidMarketId());
            interestModels[i] = new DeployJumpRateModelV4()
                .run(string.concat(PREFIX_INTEREST_MODEL, cfg.hostMarketIds[i]), configPath, outputPath);
        }
    }

    /// @notice Deploys host or extension markets based on target chain mode
    /// @param cfg Parsed new-market deployment config
    /// @param core Existing core contract addresses
    /// @param interestModels Deployed host-chain interest models
    /// @return hostMarkets Deployed host market addresses
    /// @return extensionMarkets Deployed extension market addresses
    function _deployMarkets(
        NewMarketDeploymentConfig memory cfg,
        CoreContracts memory core,
        address[] memory interestModels
    ) internal returns (address[] memory hostMarkets, address[] memory extensionMarkets) {
        // Effects: deploy only host markets on host chain
        if (cfg.isHostChain) {
            uint256 length = cfg.hostMarketIds.length;
            hostMarkets = new address[](length);
            extensionMarkets = new address[](0);

            for (uint256 i; i < length; ++i) {
                hostMarkets[i] = _deployHostMarket(cfg, core, interestModels[i], cfg.hostMarketIds[i]);
            }
            return (hostMarkets, extensionMarkets);
        }

        // Effects: deploy only extension markets on extension chain
        uint256 extensionMarketsLength = cfg.extensionMarketIds.length;
        hostMarkets = new address[](0);
        extensionMarkets = new address[](extensionMarketsLength);

        for (uint256 i; i < extensionMarketsLength; ++i) {
            extensionMarkets[i] = _deployExtensionMarket(core, cfg.extensionMarketIds[i]);
        }
    }

    /// @notice Deploys one host market with post-deploy gas helper, pauser registration, and allowed chains
    /// @param cfg Parsed new-market deployment config
    /// @param core Existing core contract addresses
    /// @param interestModel Deployed interest model for this market
    /// @param marketId Configured host market identifier
    /// @return hostMarket Deployed host market address
    function _deployHostMarket(
        NewMarketDeploymentConfig memory cfg,
        CoreContracts memory core,
        address interestModel,
        string memory marketId
    ) internal returns (address hostMarket) {
        require(bytes(marketId).length > 0, InvalidMarketId());

        string memory hostMarketNamespace = _buildHostMarketNamespace(marketId);
        string memory setGasHelperNamespace = _buildMarketStepNamespace("setGasHelper", hostMarketNamespace);

        // Interactions: deploy host market and apply gas helper override
        hostMarket = new DeployHostMarket().withOperator(core.operator).withZkVerifier(core.zkVerifier)
            .withRoles(core.roles).withInterestModel(interestModel).run(hostMarketNamespace, configPath, outputPath);
        new SetGasHelper().withMarket(hostMarket).withGasHelper(core.gasHelper)
            .run(setGasHelperNamespace, configPath, outputPath);

        // Interactions: register host market in pauser and update allowed chain list
        vm.startBroadcast();
        Pauser(core.pauser).addPausableMarket(hostMarket, IPauser.PausableType.Host);
        for (uint256 i; i < cfg.hostAllowedChainIds.length; ++i) {
            uint256 chainId = cfg.hostAllowedChainIds[i];
            require(chainId == uint256(uint32(chainId)), InvalidChainId(chainId));
            mErc20Host(payable(hostMarket)).updateAllowedChain(uint32(chainId), true);
        }
        vm.stopBroadcast();
    }

    /// @notice Deploys one extension market with pauser registration
    /// @param core Existing core contract addresses
    /// @param marketId Configured extension market identifier
    /// @return extensionMarket Deployed extension market address
    function _deployExtensionMarket(CoreContracts memory core, string memory marketId)
        internal
        returns (address extensionMarket)
    {
        require(bytes(marketId).length > 0, InvalidMarketId());

        // Interactions: deploy extension market with dependency overrides
        extensionMarket = new DeployExtensionMarket().withBlacklister(core.blacklister).withZkVerifier(core.zkVerifier)
            .withRoles(core.roles).run(string.concat(PREFIX_EXTENSION_MARKET, marketId), configPath, outputPath);

        // Interactions: register extension market in pauser contract
        vm.startBroadcast();
        Pauser(core.pauser).addPausableMarket(extensionMarket, IPauser.PausableType.Extension);
        vm.stopBroadcast();
    }

    /// @notice Writes merged aggregated deployment summary back to shared output
    /// @param summary Updated deployment summary
    /// @param outputFilePath Absolute output file path
    function _writeAggregatedOutput(ExistingDeploymentSummary memory summary, string memory outputFilePath) internal {
        // Effects: serialize merged deployment summary payload
        string memory json = OUTPUT_NEW_CHAIN;

        vm.serializeBool(json, "isHostChain", summary.isHostChain);
        vm.serializeAddress(json, "roles", summary.core.roles);
        vm.serializeAddress(json, "blacklister", summary.core.blacklister);
        vm.serializeAddress(json, "zkVerifier", summary.core.zkVerifier);
        vm.serializeAddress(json, "batchSubmitter", summary.core.batchSubmitter);
        vm.serializeAddress(json, "timelockController", summary.core.timelockController);
        vm.serializeAddress(json, "gasHelper", summary.core.gasHelper);
        vm.serializeAddress(json, "rewardDistributor", summary.core.rewardDistributor);
        vm.serializeAddress(json, "oracle", summary.core.oracle);
        vm.serializeAddress(json, "operator", summary.core.operator);
        vm.serializeAddress(json, "pauser", summary.core.pauser);
        vm.serializeAddress(json, "rebalancer", summary.core.rebalancer);
        vm.serializeAddress(json, "acrossBridge", summary.core.acrossBridge);
        vm.serializeAddress(json, "everclearBridge", summary.core.everclearBridge);
        vm.serializeAddress(json, "hostMarkets", summary.hostMarkets);
        vm.serializeAddress(json, "extensionMarkets", summary.extensionMarkets);
        string memory serialized = vm.serializeAddress(json, "interestModels", summary.interestModels);

        // Interactions: write merged summary under deployNewChain namespace
        vm.writeJson(
            serialized, outputFilePath, JsonReader.getPropertyPath(OUTPUT_NEW_CHAIN, OUTPUT_DEPLOYED_CONTRACTS)
        );
    }

    ////////////////////////////////////////////////////////////
    //                    View / Pure Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Concatenates two address arrays preserving order
    /// @param left Existing addresses
    /// @param right Newly deployed addresses
    /// @return values Concatenated address array
    function _concat(address[] memory left, address[] memory right) internal pure returns (address[] memory values) {
        values = new address[](left.length + right.length);

        for (uint256 i; i < left.length; ++i) {
            values[i] = left[i];
        }
        for (uint256 i; i < right.length; ++i) {
            values[left.length + i] = right[i];
        }
    }

    /// @notice Builds host-market namespace key from market identifier
    /// @param marketId Market identifier from config
    /// @return namespace_ Host-market section key
    function _buildHostMarketNamespace(string memory marketId) internal pure returns (string memory namespace_) {
        namespace_ = string.concat(PREFIX_HOST_MARKET, marketId);
    }

    /// @notice Builds market-step namespace key for market-specific function calls
    /// @param defaultNamespace Default function namespace prefix
    /// @param marketNamespace Host-market section namespace suffix
    /// @return namespace_ Composed function-call section key
    function _buildMarketStepNamespace(string memory defaultNamespace, string memory marketNamespace)
        internal
        pure
        returns (string memory namespace_)
    {
        namespace_ = string.concat(defaultNamespace, "__", marketNamespace);
    }
}
