// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {DeployerUtil} from "script/utils/DeployerUtil.sol";
import {Logger} from "script/utils/Logger.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";

abstract contract FunctionCallScriptBase is ScriptBase {
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the function call fails
    error FunctionCallFailed(bytes err);

    ////////////////////////////////////////////////////////////
    //                       Modifiers                        //
    ////////////////////////////////////////////////////////////

    /// @notice Logs the deployment step and the separator before and after the function call
    modifier functionCallLogWrapper() {
        Logger.functionCall(_defaultNamespace());
        _;
        Logger.separatorTilda();
    }

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc ScriptBase
    function run() public override returns (address) {
        // Interactions: run the script
        return _run();
    }

    /// @inheritdoc ScriptBase
    function run(string memory configPath_, string memory outputPath_) public override returns (address) {
        // Effects: set the config path and output path
        setConfigPath(configPath_);
        setOutputPath(outputPath_);

        // Interactions: run the script
        return _run();
    }

    /// @inheritdoc ScriptBase
    function run(string memory namespace_, string memory configPath_, string memory outputPath_)
        public
        override
        returns (address)
    {
        // Effects: set the namespace, config path and output path
        setNamespace(namespace_);
        setConfigPath(configPath_);
        setOutputPath(outputPath_);

        // Interactions: run the script
        return _run();
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    function _run() internal virtual functionCallLogWrapper returns (address) {
        // Load the deploy config
        bytes memory cfg = _loadAndValidateConfig();

        string memory outputFilePath = _getOutputFilePath();
        if (bytes(outputFilePath).length > 0) {
            // Effects: create an empty output JSON file, if necessary
            DeployerUtil.createEmptyOutputJsonFile(vm, outputFilePath);

            // Effects: Write the final config to the output JSON file, if provided
            writeFinalConfigToOutput(cfg);
        }

        // Interactions: call the function and assert the resulting contract's state
        (bool success, bytes memory err) = _callFunctionAndAssertResult(cfg);

        // Log the function call result
        Logger.functionResult(_defaultNamespace(), success, err);

        require(success, FunctionCallFailed(err));

        return address(0);
    }

    /// @notice Calls the function and asserts the resulting contract's state
    /// @dev This function must be overridden by the child contract
    /// @param config The encoded config
    function _callFunctionAndAssertResult(bytes memory config) internal virtual returns (bool success, bytes memory err);
}
