// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeploymentScriptBase} from "script/utils/DeploymentScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {Deployer} from "src/utils/Deployer.sol";

/// @title DeployZkVerifier
/// @author Merge Layers Inc.
/// @notice Single deployment script that deploys ZkVerifier
contract DeployZkVerifier is DeploymentScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice Config value for deployer
        address deployer;
        /// @notice Config value for owner
        address owner;
        /// @notice Config value for verifier
        address verifier;
        /// @notice Config value for imageId
        bytes32 imageId;
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
    /// @notice Error thrown when verifier is invalid
    error InvalidVerifier();
    /// @notice Error thrown when image id is invalid
    error InvalidImageId();
    /// @notice Error thrown when salt is invalid
    error InvalidSalt();
    /// @notice Error thrown when zk verifier address is invalid
    error InvalidZkVerifierAddress();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc DeploymentScriptBase
    function _deployAndAssertResult(bytes memory deployConfig) internal override returns (address zkVerifierAddress) {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        Deployer deployer = Deployer(payable(cfg.deployer));

        // Interactions: precompute deterministic deployment address
        bytes32 salt = keccak256(bytes(cfg.salt));
        zkVerifierAddress = deployer.precompute(salt);
        if (zkVerifierAddress.code.length == 0) {
            bytes memory callData = abi.encodeWithSelector(
                deployer.create.selector,
                salt,
                abi.encodePacked(type(ZkVerifier).creationCode, abi.encode(cfg.owner, cfg.imageId, cfg.verifier))
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

            zkVerifierAddress = abi.decode(returnData, (address));
        }

        // Requirements: zkVerifierAddress should not be the zero address; zkVerifierAddress code length should be greater than
        // zero.
        require(zkVerifierAddress != address(0), InvalidZkVerifierAddress());
        require(zkVerifierAddress.code.length > 0, InvalidZkVerifierAddress());

        ZkVerifier zkVerifier = ZkVerifier(zkVerifierAddress);
        // Requirements: owner should equal cfg.owner; verifier should equal cfg.verifier; imageId should equal cfg.imageId.
        require(zkVerifier.owner() == cfg.owner, InvalidOwner());
        require(address(zkVerifier.verifier()) == cfg.verifier, InvalidVerifier());
        require(zkVerifier.imageId() == cfg.imageId, InvalidImageId());
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
        vm.serializeAddress(json, "verifier", cfg.verifier);
        vm.serializeBytes32(json, "imageId", cfg.imageId);
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
        cfg.verifier = _readAndLogAddress(json, "verifier");
        cfg.imageId = _readAndLogBytes32(json, "imageId");
        cfg.salt = _readAndLogString(json, "salt");

        // Requirement: all conditions must be satisfied
        require(cfg.deployer != address(0), InvalidDeployer());
        require(cfg.owner != address(0), InvalidOwner());
        require(cfg.verifier != address(0), InvalidVerifier());
        require(cfg.imageId != bytes32(0), InvalidImageId());
        require(bytes(cfg.salt).length > 0, InvalidSalt());

        // Effects: return encoded config for base runner
        deployConfig = abi.encode(cfg);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "ZkVerifier";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployZkVerifier.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/deploy/single/DeployZkVerifier.output.json";
    }
}
