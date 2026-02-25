// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Blacklister} from "src/blacklister/Blacklister.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployBlacklister
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys Blacklister implementation + proxy
contract DeployBlacklister is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for roles
        address roles;
        /// @notice Config value for owner
        address owner;
        /// @notice Config value for implementationSalt
        string implementationSalt;
        /// @notice Config value for proxySalt
        string proxySalt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when roles is invalid
    error InvalidRoles();
    /// @notice Error thrown when owner is invalid
    error InvalidOwner();
    /// @notice Error thrown when implementation salt is invalid
    error InvalidImplementationSalt();
    /// @notice Error thrown when proxy salt is invalid
    error InvalidProxySalt();
    /// @notice Error thrown when proxy address is invalid
    error InvalidProxyAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address blacklisterAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address for implementation
        bytes32 implementationSalt = keccak256(bytes(cfg.implementationSalt));
        address implementation = deployer.precompute(implementationSalt);
        if (implementation.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector, implementationSalt, abi.encodePacked(type(Blacklister).creationCode)
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

            implementation = abi.decode(returnData, (address));
        }

        // Interactions: precompute deterministic deployment address for proxy
        bytes32 proxySalt = keccak256(bytes(cfg.proxySalt));
        blacklisterAddress = deployer.precompute(proxySalt);
        if (blacklisterAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                proxySalt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implementation,
                        cfg.owner,
                        abi.encodeWithSelector(Blacklister.initialize.selector, cfg.owner, cfg.roles)
                    )
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

            blacklisterAddress = abi.decode(returnData, (address));
        }

        // Requirement: all conditions must be satisfied
        require(blacklisterAddress != address(0), InvalidProxyAddress());
        require(blacklisterAddress.code.length > 0, InvalidProxyAddress());
        require(Blacklister(blacklisterAddress).owner() == cfg.owner, InvalidOwner());
        require(address(Blacklister(blacklisterAddress).rolesOperator()) == cfg.roles, InvalidRoles());
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
        vm.serializeAddress(json, "owner", cfg.owner);
        vm.serializeString(json, "implementationSalt", cfg.implementationSalt);
        serialized = vm.serializeString(json, "proxySalt", cfg.proxySalt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.implementationSalt = _readAndLogString(json, "implementationSalt");
        cfg.proxySalt = _readAndLogString(json, "proxySalt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.roles != address(0), InvalidRoles());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.implementationSalt).length > 0, InvalidImplementationSalt());
        require(bytes(cfg.proxySalt).length > 0, InvalidProxySalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "Blacklister";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployBlacklister.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployBlacklister.output.json";
    }
}
