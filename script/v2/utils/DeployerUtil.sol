// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {JsonReader} from "script/v2/utils/JsonReader.sol";

library DeployerUtil {
    string internal constant DEPLOYED_CONTRACTS_KEY = "deployedContracts";

    function createEmptyOutputJsonFile(Vm vm, string memory outputPath) internal {
        if (!vm.exists(outputPath)) {
            vm.writeLine(outputPath, "{}");
        }
    }

    function seedOutputJsonForDeployment(Vm vm, string memory outputPath) internal {
        createEmptyOutputJsonFile(vm, outputPath);

        if (!vm.keyExistsJson(vm.readFile(outputPath), JsonReader.getPropertyPath(DEPLOYED_CONTRACTS_KEY))) {
            vm.writeJson("{}", outputPath, JsonReader.getPropertyPath(DEPLOYED_CONTRACTS_KEY));
        }
    }

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
