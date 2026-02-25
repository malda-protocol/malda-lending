// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Migrator} from "src/migration/Migrator.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployMigrator
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys Migrator
contract DeployMigrator is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for operator
        address operator;
        /// @notice Config value for salt
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when migrator address is invalid
    error InvalidMigratorAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address migratorAddress) {
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        migratorAddress = deployer.precompute(salt);
        if (migratorAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector, salt, abi.encodePacked(type(Migrator).creationCode, abi.encode(cfg.operator))
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

            migratorAddress = abi.decode(returnData, (address));
        }

        // Requirements: migratorAddress should not be the zero address; migratorAddress code length should be greater than zero;
        // malda operator should equal cfg.operator.
        require(migratorAddress != address(0), InvalidMigratorAddress());
        require(migratorAddress.code.length > 0, InvalidMigratorAddress());
        require(Migrator(migratorAddress).MALDA_OPERATOR() == cfg.operator, InvalidOperator());
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
        vm.serializeAddress(json, "operator", cfg.operator);
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirements: cfg.deployer should not be the zero address; cfg.operator should not be the zero address; cfg.salt should
        // not be empty.
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.operator != address(0), InvalidOperator());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "Migrator";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMigrator.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployMigrator.output.json";
    }
}
