// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetCloseFactor
/// @notice Function-call script that sets close factor on Operator
contract SetCloseFactor is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator.sol contract
        address operator;
        /// @notice The close factor mantissa to set
        uint256 factor;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator address is invalid
    error InvalidOperator();
    /// @notice Error thrown when the close factor read fails
    error CloseFactorReadFailed();
    /// @notice Error thrown when the close factor mismatch occurs
    error CloseFactorMismatch(uint256 expected, uint256 actual);

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

        // Interactions: read current close factor from operator
        (bool readBeforeSuccess, uint256 currentFactor) = _readCloseFactor(cfg.operator);

        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(CloseFactorReadFailed.selector));
        }

        // Effects + Requirements: short-circuit if requested close factor is already set; skip mutation when current factor
        // already equals cfg.factor.
        if (currentFactor == cfg.factor) {
            return (true, bytes(""));
        }
        bytes memory callData = abi.encodeWithSelector(Operator.setCloseFactor.selector, cfg.factor);
        Logger.logCalldata("Operator", cfg.operator, "setCloseFactor", callData);

        // Interactions: perform setCloseFactor call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.operator).call(callData);
        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        // Interactions: read close factor after the call for invariant checks
        (bool readAfterSuccess, uint256 updatedFactor) = _readCloseFactor(cfg.operator);

        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(CloseFactorReadFailed.selector));
        }

        // Requirements: updated factor should equal cfg.factor after the call.
        if (updatedFactor != cfg.factor) {
            return (false, abi.encodeWithSelector(CloseFactorMismatch.selector, cfg.factor, updatedFactor));
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
        vm.serializeAddress(json, "operator", cfg.operator);
        serialized = vm.serializeUint(json, "factor", cfg.factor);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;

        // Read config: operator, factor
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.factor = _readAndLogUint(json, "factor");

        // Requirement: cfg.operator should not be the zero address.
        require(cfg.operator != address(0), InvalidOperator());

        // Effects: return encoded validated config to base runner
        deployConfig = abi.encode(cfg);
    }

    /// @notice Reads the close factor from the operator
    /// @param operator The address of the operator
    /// @return success Whether the close factor read was successful
    /// @return factor The close factor mantissa
    function _readCloseFactor(address operator) internal view returns (bool success, uint256 factor) {
        // Interactions: query close factor using operator public getter
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("closeFactorMantissa()"));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, 0);
        }

        // Effects: decode returned close factor value
        factor = abi.decode(data, (uint256));
        return (true, factor);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setCloseFactor";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetCloseFactor.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetCloseFactor.output.json";
    }
}
