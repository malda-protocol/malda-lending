// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeployerUtil} from "script/v2/utils/DeployerUtil.sol";
import {JsonReader} from "script/v2/utils/JsonReader.sol";
import {Logger} from "script/v2/utils/Logger.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

abstract contract DeploymentScriptBase is ScriptBase {
    bool internal immutable FORCE_DEPLOY;

    modifier deploymentLogWrapper() {
        Logger.deploymentStep(namespace, block.chainid);
        _;
        Logger.separatorHyphen();
    }

    constructor() {
        FORCE_DEPLOY = vm.envOr("FORCE_DEPLOY", false);
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

    function _run() internal deploymentLogWrapper returns (address contractAddress) {
        Logger.logConfigPath(_getConfigFilePath());

        bytes memory cfg = _loadAndValidateConfig();

        string memory outputFilePath = _getOutputFilePath();
        if (bytes(outputFilePath).length > 0) {
            Logger.logOutputPath(outputFilePath, true);
            DeployerUtil.seedOutputJsonForDeployment(vm, outputFilePath);
            writeFinalConfigToOutput(cfg);
            Logger.logOutputPath(outputFilePath, false);

            if (!FORCE_DEPLOY && vm.keyExistsJson(vm.readFile(outputFilePath), _deployedContractPath())) {
                address existingAddress = JsonReader.readAddress(vm.readFile(outputFilePath), _deployedContractPath());
                if (existingAddress != address(0) && existingAddress.code.length > 0) {
                    Logger.deploymentSkipped(namespace, existingAddress);
                    return existingAddress;
                }
            }
        }

        contractAddress = _deployAndAssertResult(cfg);
        Logger.deploymentResult(namespace, _defaultNamespace(), contractAddress);

        _postDeploymentConfiguration(cfg, contractAddress);

        if (bytes(outputFilePath).length > 0) {
            vm.writeJson(
                vm.serializeAddress(DeployerUtil.DEPLOYED_CONTRACTS_KEY, namespace, contractAddress),
                outputFilePath,
                JsonReader.getPropertyPath(DeployerUtil.DEPLOYED_CONTRACTS_KEY)
            );
        }
    }

    function _deployAndAssertResult(bytes memory deployConfig) internal virtual returns (address contractAddress);

    function _postDeploymentConfiguration(bytes memory deployConfig, address contractAddress) internal virtual {}

    function _deployedContractPath() internal view returns (string memory) {
        return JsonReader.getPropertyPath(DeployerUtil.DEPLOYED_CONTRACTS_KEY, namespace);
    }
}
