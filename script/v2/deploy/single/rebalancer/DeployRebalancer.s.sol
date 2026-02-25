// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployRebalancer
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys Rebalancer
contract DeployRebalancer is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for roles
        address roles;
        /// @notice Config value for saveAddress
        address saveAddress;
        /// @notice Config value for admin
        address admin;
        /// @notice Config value for initData
        bytes initData;
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
    /// @notice Error thrown when save address is invalid
    error InvalidSaveAddress();
    /// @notice Error thrown when admin is invalid
    error InvalidAdmin();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when rebalancer address is invalid
    error InvalidRebalancerAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address rebalancerAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        rebalancerAddress = deployer.precompute(salt);
        if (rebalancerAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(
                    type(Rebalancer).creationCode, abi.encode(cfg.roles, cfg.saveAddress, cfg.admin, cfg.initData)
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

            rebalancerAddress = abi.decode(returnData, (address));
        }

        // Requirements: rebalancerAddress should not be the zero address; rebalancerAddress code length should be greater than
        // zero.
        require(rebalancerAddress != address(0), InvalidRebalancerAddress());
        require(rebalancerAddress.code.length > 0, InvalidRebalancerAddress());

        Rebalancer rebalancer = Rebalancer(rebalancerAddress);
        // Requirements: roles should equal cfg.roles; saveAddress should equal cfg.saveAddress; admin should equal cfg.admin.
        require(address(rebalancer.roles()) == cfg.roles, InvalidRoles());
        require(rebalancer.saveAddress() == cfg.saveAddress, InvalidSaveAddress());
        require(rebalancer.admin() == cfg.admin, InvalidAdmin());
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
        vm.serializeAddress(json, "saveAddress", cfg.saveAddress);
        vm.serializeAddress(json, "admin", cfg.admin);
        vm.serializeBytes(json, "initData", cfg.initData);
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
        cfg.saveAddress = _readAndLogAddress(json, "saveAddress");
        cfg.admin = _readAndLogAddress(json, "admin");
        cfg.initData = _readAndLogBytes(json, "initData");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.roles != address(0), InvalidRoles());
        require(cfg.saveAddress != address(0), InvalidSaveAddress());
        require(cfg.admin != address(0), InvalidAdmin());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "Rebalancer";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployRebalancer.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployRebalancer.output.json";
    }
}
