// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {DeployerUtil} from "script/v2/utils/DeployerUtil.sol";
import {JsonReader} from "script/v2/utils/JsonReader.sol";
import {Logger} from "script/v2/utils/Logger.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

/// @title DeploymentScriptBase
/// @author Malda Protocol
/// @notice Base contract for deployment scripts
abstract contract DeploymentScriptBase is ScriptBase {
    /// @notice Whether to force the deployment of the contract. Defaults to false.
    bool internal immutable FORCE_DEPLOY;

    /// @notice Logs the deployment step and the separator before and after the function call.
    modifier deploymentLogWrapper() {
        Logger.deploymentStep(namespace, block.chainid);
        _;
        Logger.separatorHyphen();
    }

    /// @notice Constructor
    /// @dev Sets the FORCE_DEPLOY variable to the value of the FORCE_DEPLOY environment variable, or false if the
    /// environment variable is not set.
    constructor() {
        FORCE_DEPLOY = vm.envOr("FORCE_DEPLOY", false);
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

    /// @notice Runs the deployment script
    /// @dev This function is the entry point for the deployment script
    /// @return contractAddress The address of the deployed contract
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

    /// @notice Deploys the contract and asserts the resulting contract's state
    /// @param deployConfig The deploy config
    /// @return contractAddress The address of the deployed contract
    function _deployAndAssertResult(bytes memory deployConfig) internal virtual returns (address contractAddress);

    /// @notice Performs post-deployment configuration
    /// @param deployConfig The deploy config
    /// @param contractAddress The address of the deployed contract
    function _postDeploymentConfiguration(bytes memory deployConfig, address contractAddress) internal virtual {}

    /// @notice Builds the path to the deployed contract in the output JSON file
    /// @return deployedContractPath The path to the deployed contract
    function _deployedContractPath() internal view returns (string memory) {
        return JsonReader.getPropertyPath(DeployerUtil.DEPLOYED_CONTRACTS_KEY, namespace);
    }
}
