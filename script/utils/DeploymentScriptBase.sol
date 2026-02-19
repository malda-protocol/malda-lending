// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Role} from "script/deploy/Types.sol";
import {DeployerUtil} from "script/utils/DeployerUtil.sol";
import {JsonReader} from "script/utils/JsonReader.sol";
import {Logger} from "script/utils/Logger.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";

abstract contract DeploymentScriptBase is ScriptBase {
    ////////////////////////////////////////////////////////////
    //                       Immutables                       //
    ////////////////////////////////////////////////////////////

    /// @notice Whether to force the deployment of the contract
    bool internal immutable FORCE_DEPLOY;

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    error ExpectedAddressMismatch();

    ////////////////////////////////////////////////////////////
    //                       Modifiers                        //
    ////////////////////////////////////////////////////////////

    /// @notice Logs the deployment step and the separator before and after the function call
    modifier deploymentLogWrapper() {
        Logger.deploymentStep(namespace, block.chainid);
        _;
        Logger.separatorHyphen();
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    constructor() {
        FORCE_DEPLOY = vm.envBool("FORCE_DEPLOY");
    }

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

    /// @inheritdoc ScriptBase
    function run() public override returns (address) {
        // Interactions: run the deployment script
        return _run();
    }

    /// @inheritdoc ScriptBase
    function run(string memory configPath_, string memory outputPath_) public override returns (address) {
        // Effects: set the config path and output path
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
        // Effects: set the namespace and config path
        setNamespace(namespace_);
        setConfigPath(configPath_);
        setOutputPath(outputPath_);

        // Interactions: run the deployment script
        return _run();
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Runs the deployment script and returns the namespace and contract address
    /// @dev This function must be overridden by the child contract
    /// @return contractAddress The address of the deployed contract
    function _run() internal deploymentLogWrapper returns (address) {
        string memory outputFilePath = _getOutputFilePath();
        bool doesOutputFileExist = bytes(outputFilePath).length > 0;

        // If FORCE_DEPLOY is false, we can skip the deployment if the contract is already deployed
        if (doesOutputFileExist && !FORCE_DEPLOY) {
            // Check if the contract is already deployed
            address expectedAddress = JsonReader.readAddress(
                vm.readFile(outputFilePath), JsonReader.getPropertyPath(DeployerUtil.DEPLOYED_CONTRACTS_KEY, namespace)
            );

            // If yes, return the expected address and log that deployment was skipped
            if (expectedAddress != address(0)) {
                Logger.deploymentSkipped(namespace, expectedAddress);
                return expectedAddress;
            }
        }

        // Load the deploy config
        bytes memory cfg = _loadAndValidateConfig();
        if (doesOutputFileExist) {
            // Effects: seed the output JSON file by setting the top level keys, if necessary
            DeployerUtil.seedOutputJsonForDeployment(vm, outputFilePath);

            // Effects: Write the final config to the output JSON file, if provided (only for multi-contract
            // deployments)
            writeFinalConfigToOutput(cfg);
        }

        // Interactions: deploy the contract and assert the resulting contract's state
        address contractAddress = _deployAndAssertResult(cfg);

        // Log the deployment result
        Logger.deploymentResult(namespace, _defaultNamespace(), contractAddress);

        // Effects: perform post-deployment configuration
        _postDeploymentConfiguration(cfg, contractAddress);

        // Effects: record the deployed contract
        vm.writeJson(
            vm.serializeAddress(DeployerUtil.DEPLOYED_CONTRACTS_KEY, namespace, contractAddress),
            outputFilePath,
            JsonReader.getPropertyPath(DeployerUtil.DEPLOYED_CONTRACTS_KEY)
        );

        return contractAddress;
    }

    /// @notice Deploys the contract and asserts the resulting contract's state
    /// @dev This function must be overridden by the child contract
    /// @param deployConfig The encoded deploy config
    function _deployAndAssertResult(bytes memory deployConfig) internal virtual returns (address contractAddress);

    /// @notice Performs post-deployment configuration
    /// @dev This function must be overridden by the child contract
    /// @param contractAddress The address of the deployed contract
    function _postDeploymentConfiguration(bytes memory deployConfig, address contractAddress) internal virtual {}

    /// @notice Loads the roles from the JSON file
    /// @dev This function must be overridden by the child contract
    /// @return roles The encoded roles
    function _loadRoles() internal view virtual returns (bytes memory roles) {}

    ////////////////////////////////////////////////////////////
    //                      Config Utils                      //
    ////////////////////////////////////////////////////////////

    /// @notice Reads a role from JSON
    /// @param json Raw JSON string
    /// @param roleName The role name
    /// @return role The role
    function _readRole(string memory json, string memory roleName) internal view returns (Role memory role) {
        role.id = uint8(JsonReader.readUint(json, JsonReader.getPropertyPath("roles", roleName, "id")));
        role.users = JsonReader.readAddressArray(json, JsonReader.getPropertyPath("roles", roleName, "users"));
    }
}
