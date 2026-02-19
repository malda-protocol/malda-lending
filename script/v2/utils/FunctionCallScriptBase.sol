// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeployerUtil} from "script/v2/utils/DeployerUtil.sol";
import {Logger} from "script/v2/utils/Logger.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

abstract contract FunctionCallScriptBase is ScriptBase {
    error FunctionCallFailed(bytes err);

    modifier functionCallLogWrapper() {
        Logger.functionCall(namespace);
        _;
        Logger.separatorTilda();
    }

    function run() public override returns (address) {
        return _run();
    }

    function run(string memory configPath_, string memory outputPath_) public override returns (address) {
        setConfigPath(configPath_);
        setOutputPath(outputPath_);

        return _run();
    }

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

    function _callFunctionAndAssertResult(bytes memory config) internal virtual returns (bool success, bytes memory err);
}
