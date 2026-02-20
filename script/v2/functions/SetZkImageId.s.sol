// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/v2/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

/// @title SetZkImageId
/// @notice Function-call script that sets image id on ZkVerifier
contract SetZkImageId is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the ZkVerifier contract
        address zkVerifier;
        /// @notice The image id to set
        bytes32 imageId;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the zk verifier is invalid
    error InvalidZkVerifier();
    /// @notice Error thrown when the image id is invalid
    error InvalidImageId();
    /// @notice Error thrown when image id read fails
    error ImageIdReadFailed();
    /// @notice Error thrown when image id mismatch occurs
    error ImageIdMismatch(bytes32 expected, bytes32 actual);

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////
    /// @inheritdoc FunctionCallScriptBase
    function _callFunctionAndAssertResult(bytes memory deployConfig)
        internal
        override
        returns (bool success, bytes memory err)
    {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        (bool readBeforeSuccess, bytes32 currentImageId) = _readImageId(cfg.zkVerifier);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(ImageIdReadFailed.selector));
        }

        // Effects: short-circuit when requested value is already set
        if (currentImageId == cfg.imageId) {
            return (true, bytes(""));
        }
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) =
            address(cfg.zkVerifier).call(abi.encodeWithSelector(ZkVerifier.setImageId.selector, cfg.imageId));
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, bytes32 updatedImageId) = _readImageId(cfg.zkVerifier);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(ImageIdReadFailed.selector));
        }

        // Requirements: resulting onchain state must match requested value
        if (updatedImageId != cfg.imageId) {
            return (false, abi.encodeWithSelector(ImageIdMismatch.selector, cfg.imageId, updatedImageId));
        }

        return (true, bytes(""));
    }

    /// @inheritdoc ScriptBase
    function _serializeConfig(bytes memory config, string memory namespace_)
        internal
        override
        returns (string memory serialized)
    {
        // Effects: decode final config for output serialization
        DeployConfig memory cfg = abi.decode(config, (DeployConfig));
        // Effects: serialize final resolved config under script namespace
        string memory json = namespace_;
        vm.serializeAddress(json, "zkVerifier", cfg.zkVerifier);
        serialized = vm.serializeBytes32(json, "imageId", cfg.imageId);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.zkVerifier = _readAndLogAddress(json, "zkVerifier");
        cfg.imageId = _readAndLogBytes32(json, "imageId");

        require(cfg.zkVerifier != address(0), InvalidZkVerifier());
        require(cfg.imageId != bytes32(0), InvalidImageId());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readImageId(address zkVerifier) internal view returns (bool success, bytes32 imageId) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) = address(zkVerifier).staticcall(abi.encodeWithSignature("imageId()"));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 32) {
            return (false, bytes32(0));
        }

        // Effects: decode returned state value from payload
        imageId = abi.decode(data, (bytes32));
        return (true, imageId);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setZkImageId";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetZkImageId.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetZkImageId.output.json";
    }
}
