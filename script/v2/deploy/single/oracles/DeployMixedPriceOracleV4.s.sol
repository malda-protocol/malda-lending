// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployMixedPriceOracleV4
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys MixedPriceOracleV4 with optional encoded feeds
contract DeployMixedPriceOracleV4 is DeploymentScriptBase {
    struct FeedConfig {
        string symbol;
        address api3Feed;
        address chainlinkFeed;
        string api3ToSymbol;
        string chainlinkToSymbol;
        uint256 underlyingDecimals;
    }

    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for roles
        address roles;
        /// @notice Config value for stalenessPeriod
        uint256 stalenessPeriod;
        /// @notice Config value for salt
        string salt;
        /// @notice Config value for feedsEncoded
        bytes feedsEncoded;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when roles is invalid
    error InvalidRoles();
    /// @notice Error thrown when staleness period is invalid
    error InvalidStalenessPeriod();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when oracle address is invalid
    error InvalidOracleAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address oracleAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        FeedConfig[] memory feeds;
        if (cfg.feedsEncoded.length > 0) {
            feeds = abi.decode(cfg.feedsEncoded, (FeedConfig[]));
        }

        uint256 length = feeds.length;
        string[] memory symbols = new string[](length);
        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](length);

        for (uint256 i; i < length; ++i) {
            symbols[i] = feeds[i].symbol;
            configs[i] = MixedPriceOracleV4.PriceConfig({
                api3Feed: feeds[i].api3Feed,
                chainlinkFeed: feeds[i].chainlinkFeed,
                api3ToSymbol: feeds[i].api3ToSymbol,
                chainlinkToSymbol: feeds[i].chainlinkToSymbol,
                underlyingDecimals: feeds[i].underlyingDecimals
            });
        }

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        oracleAddress = deployer.precompute(salt);
        if (oracleAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(
                    type(MixedPriceOracleV4).creationCode, abi.encode(symbols, configs, cfg.roles, cfg.stalenessPeriod)
                )
            );
            Logger.logCalldata("Deployer", cfg.deployer, "create", callData);
            // Interactions: broadcast exact logged calldata payload to deployer
            vm.broadcast();
            (bool success, bytes memory returnData) = cfg.deployer.call(callData);

            // Requirements: external call should succeed.
            if (!success) {
                assembly {
                    revert(add(returnData, 0x20), mload(returnData))
                }
            }

            oracleAddress = abi.decode(returnData, (address));
        }

        // Requirement: all conditions must be satisfied
        require(oracleAddress != address(0), InvalidOracleAddress());
        require(oracleAddress.code.length > 0, InvalidOracleAddress());
        require(address(MixedPriceOracleV4(oracleAddress).ROLES()) == cfg.roles, InvalidRoles());
        require(MixedPriceOracleV4(oracleAddress).STALENESS_PERIOD() == cfg.stalenessPeriod, InvalidStalenessPeriod());
    }

    /// @inheritdoc ScriptBase
    function _serializeConfig(bytes memory config, string memory namespace_)
        internal
        override
        returns (string memory serialized)
    {
        // Effects: decode validated config for output serialization
        DeployConfig memory cfg = abi.decode(config, (DeployConfig));

        // Effects: write resolved config values under script namespace
        string memory json = namespace_;
        vm.serializeAddress(json, "deployer", cfg.deployer);
        vm.serializeAddress(json, "roles", cfg.roles);
        vm.serializeUint(json, "stalenessPeriod", cfg.stalenessPeriod);
        vm.serializeString(json, "salt", cfg.salt);
        serialized = vm.serializeBytes(json, "feedsEncoded", cfg.feedsEncoded);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.stalenessPeriod = _readAndLogUint(json, "stalenessPeriod");
        cfg.salt = _readAndLogString(json, "salt");
        cfg.feedsEncoded = _readAndLogBytes(json, "feedsEncoded");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.roles != address(0), InvalidRoles());
        require(cfg.stalenessPeriod > 0, InvalidStalenessPeriod());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "MixedPriceOracleV4";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMixedPriceOracleV4.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMixedPriceOracleV4.output.json";
    }
}
