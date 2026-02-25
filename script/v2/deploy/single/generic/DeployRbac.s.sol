// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Roles} from "src/Roles.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployRbac
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys Roles
contract DeployRbac is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for owner
        address owner;
        /// @notice Config value for salt
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer is invalid
    error InvalidDeployer();
    /// @notice Error thrown when owner is invalid
    error InvalidOwner();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when roles address is invalid
    error InvalidRolesAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address rolesAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        rolesAddress = deployer.precompute(salt);
        if (rolesAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector, salt, abi.encodePacked(type(Roles).creationCode, abi.encode(cfg.owner))
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

            rolesAddress = abi.decode(returnData, (address));
        }

        // Requirements: rolesAddress should not be the zero address; rolesAddress code length should be greater than zero; owner
        // should equal cfg.owner.
        require(rolesAddress != address(0), InvalidRolesAddress());
        require(rolesAddress.code.length > 0, InvalidRolesAddress());
        require(Roles(rolesAddress).owner() == cfg.owner, InvalidOwner());
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
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        // Effects: read runtime config fields
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirements: cfg.deployer should not be the zero address; cfg.owner should not be the zero address; cfg.salt should
        // not be empty.
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "Roles";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployRbac.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployRbac.output.json";
    }
}
