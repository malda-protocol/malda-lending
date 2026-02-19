// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {JsonReader} from "script/utils/JsonReader.sol";

library DeployerUtil {
    ////////////////////////////////////////////////////////////
    //                       Constants                        //
    ////////////////////////////////////////////////////////////

    /// @notice The key for the deployed contracts in the output JSON file
    string internal constant DEPLOYED_CONTRACTS_KEY = "deployedContracts";

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Creates an empty output JSON file
    /// @param vm The VM instance
    /// @param outputPath The path to the output JSON file
    function createEmptyOutputJsonFile(Vm vm, string memory outputPath) internal {
        // Effects: If the JSON file doesn't exist, create it
        if (!vm.exists(outputPath)) {
            vm.writeLine(outputPath, "{}");
        }
    }

    /// @notice Initializes the output JSON file by seeding it with the `deployedContracts` key
    /// @param vm The VM instance
    /// @param outputPath The path to the output JSON file
    function seedOutputJsonForDeployment(Vm vm, string memory outputPath) internal {
        // Effects: If the JSON file doesn't exist, create it
        createEmptyOutputJsonFile(vm, outputPath);

        // Effects: If the `deployedContracts` key doesn't exist, add it
        if (!vm.keyExistsJson(vm.readFile(outputPath), JsonReader.getPropertyPath(DEPLOYED_CONTRACTS_KEY))) {
            string memory seed = string.concat("{\"", DEPLOYED_CONTRACTS_KEY, "\": {}}");
            vm.writeJson(seed, outputPath);
        }
    }

    /// @notice Builds the absolute path to the output JSON file
    /// @param vm The VM instance
    /// @param outputPath The path to the output JSON file
    /// @return absolutePath The absolute path to the output JSON file
    function buildAbsolutePath(Vm vm, string memory outputPath) internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/", outputPath);
    }
}
