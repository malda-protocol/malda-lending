// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeployerUtil} from "script/v2/utils/DeployerUtil.sol";
import {Logger} from "script/v2/utils/Logger.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

/// @title FunctionCallScriptBase
/// @author Malda Protocol
/// @notice Base contract for function call scripts
abstract contract FunctionCallScriptBase is ScriptBase {
    /// @notice Error thrown when the function call fails
    error FunctionCallFailed(bytes err);

    /// @notice Logs the function call step and the separator before and after the function call.
    modifier functionCallLogWrapper() {
        Logger.functionCall(namespace);
        _;
        Logger.separatorHyphen();
    }

    /// @inheritdoc ScriptBase
    function run() public override returns (address) {
        return _run();
    }

    /// @inheritdoc ScriptBase
    function run(string memory configPath_, string memory outputPath_) public override returns (address) {
        setConfigPath(configPath_);
        setOutputPath(outputPath_);

        return _run();
    }

    /// @inheritdoc ScriptBase
    function run(string memory namespace_, string memory configPath_, string memory outputPath_)
        public
        override
        returns (address)
    {
        setNamespace(namespace_);
        setConfigPath(configPath_);
        setOutputPath(outputPath_);

        return _run();
    }

    /// @notice Runs the function call script
    /// @dev This function is the entry point for the function call script
    /// @return contractAddress The address of the deployed contract
    function _run() internal virtual functionCallLogWrapper returns (address) {
        Logger.logConfigPath(_getConfigFilePath());

        bytes memory cfg = _loadAndValidateConfig();

        string memory outputFilePath = _getOutputFilePath();
        if (bytes(outputFilePath).length > 0) {
            Logger.logOutputPath(outputFilePath, true);
            DeployerUtil.createEmptyOutputJsonFile(vm, outputFilePath);
            writeFinalConfigToOutput(cfg);
            Logger.logOutputPath(outputFilePath, false);
        }

        (bool success, bytes memory err) = _callFunctionAndAssertResult(cfg);
        Logger.functionResult(namespace, success, err);

        require(success, FunctionCallFailed(err));

        return address(0);
    }

    /// @notice Calls the function and asserts the resulting contract's state
    /// @dev This function must be overridden by the child contract
    /// @param config The encoded config
    /// @return success Whether the function call was successful
    /// @return err The error message if the function call failed
    function _callFunctionAndAssertResult(bytes memory config) internal virtual returns (bool success, bytes memory err);
}
