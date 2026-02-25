// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {AccrossBridge} from "src/rebalancer/bridges/AcrossBridge.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployAcrossBridge
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys AcrossBridge
contract DeployAcrossBridge is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for roles
        address roles;
        /// @notice Config value for spoke
        address spoke;
        /// @notice Config value for rebalancer
        address rebalancer;
        /// @notice Config value for salt
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when roles is invalid
    error InvalidRoles();
    /// @notice Error thrown when spoke is invalid
    error InvalidSpoke();
    /// @notice Error thrown when rebalancer is invalid
    error InvalidRebalancer();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when bridge address is invalid
    error InvalidBridgeAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address bridgeAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        bridgeAddress = deployer.precompute(salt);
        if (bridgeAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(type(AccrossBridge).creationCode, abi.encode(cfg.roles, cfg.spoke, cfg.rebalancer))
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

            bridgeAddress = abi.decode(returnData, (address));
        }

        // Requirements: bridgeAddress should not be the zero address; bridgeAddress code length should be greater than zero.
        require(bridgeAddress != address(0), InvalidBridgeAddress());
        require(bridgeAddress.code.length > 0, InvalidBridgeAddress());

        AccrossBridge bridge = AccrossBridge(bridgeAddress);
        // Requirements: roles should equal cfg.roles; across spoke pool should equal cfg.spoke; rebalancer should equal
        // cfg.rebalancer.
        require(address(bridge.roles()) == cfg.roles, InvalidRoles());
        require(bridge.ACROSS_SPOKE_POOL() == cfg.spoke, InvalidSpoke());
        require(bridge.REBALANCER() == cfg.rebalancer, InvalidRebalancer());
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
        vm.serializeAddress(json, "spoke", cfg.spoke);
        vm.serializeAddress(json, "rebalancer", cfg.rebalancer);
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.spoke = _readAndLogAddress(json, "spoke");
        cfg.rebalancer = _readAndLogAddress(json, "rebalancer");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.roles != address(0), InvalidRoles());
        require(cfg.spoke != address(0), InvalidSpoke());
        require(cfg.rebalancer != address(0), InvalidRebalancer());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "AcrossBridge";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployAcrossBridge.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployAcrossBridge.output.json";
    }
}
