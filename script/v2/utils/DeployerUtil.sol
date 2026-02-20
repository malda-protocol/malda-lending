// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {JsonReader} from "script/v2/utils/JsonReader.sol";

/// @title DeployerUtil
/// @author Malda Protocol
/// @notice Utility library for deploying contracts
library DeployerUtil {
    /// @notice The key for the deployed contracts in the output JSON file
    string internal constant DEPLOYED_CONTRACTS_KEY = "deployedContracts";

    /// @notice Creates an empty output JSON file
    /// @param vm The VM instance
    /// @param outputPath The path to the output JSON file
    function createEmptyOutputJsonFile(Vm vm, string memory outputPath) internal {
        if (!vm.exists(outputPath)) {
            vm.writeLine(outputPath, "{}");
        }
    }

    /// @notice Seeds the output JSON file for deployment
    /// @param vm The VM instance
    /// @param outputPath The path to the output JSON file
    function seedOutputJsonForDeployment(Vm vm, string memory outputPath) internal {
        createEmptyOutputJsonFile(vm, outputPath);

        if (!vm.keyExistsJson(vm.readFile(outputPath), JsonReader.getPropertyPath(DEPLOYED_CONTRACTS_KEY))) {
            vm.writeJson("{}", outputPath, JsonReader.getPropertyPath(DEPLOYED_CONTRACTS_KEY));
        }
    }

    /// @notice Builds an absolute path from a relative or absolute path
    /// @param vm The VM instance
    /// @param relativeOrAbsolutePath The relative or absolute path
    /// @return absolutePath The absolute path
    function buildAbsolutePath(Vm vm, string memory relativeOrAbsolutePath)
        internal
        view
        returns (string memory absolutePath)
    {
        if (bytes(relativeOrAbsolutePath).length == 0) {
            return "";
        }

        bytes1 firstCharacter = bytes(relativeOrAbsolutePath)[0];
        if (firstCharacter == bytes1("/")) {
            return relativeOrAbsolutePath;
        }

        absolutePath = string.concat(vm.projectRoot(), "/", relativeOrAbsolutePath);
    }
}
