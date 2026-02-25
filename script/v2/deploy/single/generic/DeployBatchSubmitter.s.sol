// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployBatchSubmitter
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys BatchSubmitter
contract DeployBatchSubmitter is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Address of the configured create3 deployer contract
        address deployer;
        /// @notice Address of the roles contract used by BatchSubmitter
        address roles;
        /// @notice Address of the zk verifier contract wired into BatchSubmitter
        address zkVerifier;
        /// @notice Address that owns the deployed BatchSubmitter
        address owner;
        /// @notice Deterministic salt used for create3 deployment
        string salt;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when deployer address is zero
    error InvalidDeployer();
    /// @notice Error thrown when roles address is zero
    error InvalidRoles();
    /// @notice Error thrown when zk verifier address is zero
    error InvalidZkVerifier();
    /// @notice Error thrown when owner address is zero
    error InvalidOwner();
    /// @notice Error thrown when salt string is empty
    error InvalidSalt();
    /// @notice Error thrown when deployed BatchSubmitter address is invalid
    error InvalidBatchSubmitterAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig)
        internal
        override
        returns (address batchSubmitterAddress)
    {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        // Effects: bind configured create3 deployer and deterministic salt
        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        batchSubmitterAddress = deployer.precompute(salt);
        if (batchSubmitterAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(type(BatchSubmitter).creationCode, abi.encode(cfg.roles, cfg.zkVerifier, cfg.owner))
            );
            Logger.logCalldata("Deployer", cfg.deployer, "create", callData);

            // Interactions: deploy contract only when code is absent at precomputed address
            vm.broadcast();
            (bool success, bytes memory returnData) = cfg.deployer.call(callData);

            // Requirements: external call should succeed.
            if (!success) {
                assembly {
                    revert(add(returnData, 0x20), mload(returnData))
                }
            }

            batchSubmitterAddress = abi.decode(returnData, (address));
        }

        // Requirement: all conditions must be satisfied
        require(batchSubmitterAddress != address(0), InvalidBatchSubmitterAddress());
        require(batchSubmitterAddress.code.length > 0, InvalidBatchSubmitterAddress());
        require(BatchSubmitter(batchSubmitterAddress).owner() == cfg.owner, InvalidOwner());
        require(address(BatchSubmitter(batchSubmitterAddress).ROLES_OPERATOR()) == cfg.roles, InvalidRoles());
        require(address(BatchSubmitter(batchSubmitterAddress).verifier()) == cfg.zkVerifier, InvalidZkVerifier());
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
        vm.serializeAddress(json, "zkVerifier", cfg.zkVerifier);
        vm.serializeAddress(json, "owner", cfg.owner);
        serialized = vm.serializeString(json, "salt", cfg.salt);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load input config JSON from selected path
        string memory json = _loadConfigJson();

        // Effects: read runtime config fields
        DeployConfig memory cfg;
        cfg.deployer = _readAndLogAddress(json, "deployer");
        cfg.roles = _readAndLogAddress(json, "roles");
        cfg.zkVerifier = _readAndLogAddress(json, "zkVerifier");
        cfg.owner = _readAndLogAddress(json, "owner");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.roles != address(0), InvalidRoles());
        require(cfg.zkVerifier != address(0), InvalidZkVerifier());
        require(cfg.owner != address(0), InvalidOwner());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "BatchSubmitter";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployBatchSubmitter.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployBatchSubmitter.output.json";
    }
}
