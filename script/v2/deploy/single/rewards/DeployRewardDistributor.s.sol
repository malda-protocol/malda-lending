// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployRewardDistributor
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys RewardDistributor implementation + proxy
contract DeployRewardDistributor is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
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
    function _deployAndAssertResult(bytes memory deployConfig)
        internal
        override
        returns (address rewardDistributorAddress)
    {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 implementationSalt = keccak256(bytes(cfg.implementationSalt));
        address implementation = deployer.precompute(implementationSalt);
        if (implementation.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector, implementationSalt, type(RewardDistributor).creationCode
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

        // Interactions: precompute deterministic deployment address
        bytes32 proxySalt = keccak256(bytes(cfg.proxySalt));
        rewardDistributorAddress = deployer.precompute(proxySalt);
        if (rewardDistributorAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                proxySalt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode,
                    abi.encode(
                        implementation,
                        cfg.owner,
                        abi.encodeWithSelector(RewardDistributor.initialize.selector, cfg.owner)
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

            rewardDistributorAddress = abi.decode(returnData, (address));
        }

        // Requirements: rewardDistributorAddress should not be the zero address; rewardDistributorAddress code length should be
        // greater than zero; owner should equal cfg.owner.
        require(rewardDistributorAddress != address(0), InvalidProxyAddress());
        require(rewardDistributorAddress.code.length > 0, InvalidProxyAddress());
        require(RewardDistributor(rewardDistributorAddress).owner() == cfg.owner, InvalidOwner());
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
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.implementationSalt = _readAndLogString(json, "implementationSalt");
        cfg.proxySalt = _readAndLogString(json, "proxySalt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.implementationSalt).length > 0, InvalidImplementationSalt());
        require(bytes(cfg.proxySalt).length > 0, InvalidProxySalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "RewardDistributor";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployRewardDistributor.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployRewardDistributor.output.json";
    }
}
