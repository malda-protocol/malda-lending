// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Pauser} from "src/pauser/Pauser.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployPauser
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys Pauser
contract DeployPauser is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for roles
        address roles;
        /// @notice Config value for operator
        address operator;
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
    /// @notice Error thrown when roles is invalid
    error InvalidRoles();
    /// @notice Error thrown when operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when owner is invalid
    error InvalidOwner();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when pauser address is invalid
    error InvalidPauserAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address pauserAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        pauserAddress = deployer.precompute(salt);
        if (pauserAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(type(Pauser).creationCode, abi.encode(cfg.roles, cfg.operator, cfg.owner))
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

            pauserAddress = abi.decode(returnData, (address));
        }

        // Requirements: pauserAddress should not be the zero address; pauserAddress code length should be greater than zero.
        require(pauserAddress != address(0), InvalidPauserAddress());
        require(pauserAddress.code.length > 0, InvalidPauserAddress());

        // Requirements: owner should equal cfg.owner; roles should equal cfg.roles; operator should equal cfg.operator.
        Pauser pauser = Pauser(pauserAddress);
        require(pauser.owner() == cfg.owner, InvalidOwner());
        require(address(pauser.ROLES()) == cfg.roles, InvalidRoles());
        require(address(pauser.OPERATOR()) == cfg.operator, InvalidOperator());
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
        vm.serializeAddress(json, "operator", cfg.operator);
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
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.roles != address(0), InvalidRoles());
        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "Pauser";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployPauser.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployPauser.output.json";
    }
}
