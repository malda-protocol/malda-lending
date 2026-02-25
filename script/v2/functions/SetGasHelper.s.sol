// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

/// @title SetGasHelper
/// @notice Function-call script that sets gas helper on host market
contract SetGasHelper is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the market
        address market;
        /// @notice The address of the gas helper
        address gasHelper;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the market is invalid
    error InvalidMarket();
    /// @notice Error thrown when the gas helper is invalid
    error InvalidGasHelper();
    /// @notice Error thrown when gas helper read fails
    error GasHelperReadFailed();
    /// @notice Error thrown when gas helper mismatch occurs
    error GasHelperMismatch(address expected, address actual);

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

        (bool readBeforeSuccess, address currentGasHelper) = _readGasHelper(cfg.market);
        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(GasHelperReadFailed.selector));
        }

        // Effects + Requirements: short-circuit when requested value is already set; skip mutation when current gas helper
        // already equals cfg.gasHelper.
        if (currentGasHelper == cfg.gasHelper) {
            return (true, bytes(""));
        }
        bytes memory callData = abi.encodeWithSelector(mErc20Host.setGasHelper.selector, cfg.gasHelper);
        Logger.logCalldata("mErc20Host", cfg.market, "setGasHelper", callData);
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.market).call(callData);
        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, address updatedGasHelper) = _readGasHelper(cfg.market);
        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(GasHelperReadFailed.selector));
        }

        // Requirements: updated gas helper should equal cfg.gasHelper after the call.
        if (updatedGasHelper != cfg.gasHelper) {
            return (false, abi.encodeWithSelector(GasHelperMismatch.selector, cfg.gasHelper, updatedGasHelper));
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
        vm.serializeAddress(json, "market", cfg.market);
        serialized = vm.serializeAddress(json, "gasHelper", cfg.gasHelper);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.market = _readAndLogAddress(json, "market");
        cfg.gasHelper = _readAndLogAddress(json, "gasHelper");

        // Requirements: cfg.market should not be the zero address; cfg.gasHelper should not be the zero address.
        require(cfg.market != address(0), InvalidMarket());
        require(cfg.gasHelper != address(0), InvalidGasHelper());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readGasHelper(address market) internal view returns (bool success, address gasHelper) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) = address(market).staticcall(abi.encodeWithSignature("gasHelper()"));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, address(0));
        }

        // Effects: decode returned state value from payload
        gasHelper = abi.decode(data, (address));
        return (true, gasHelper);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setGasHelper";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetGasHelper.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetGasHelper.output.json";
    }
}
