// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {console} from "forge-std/console.sol";

library Logger {
    function logConfigPath(string memory configPath) internal pure {
        console.log("\t>>> Using config path '%s'", configPath);
    }

    function logOutputPath(string memory outputPath, bool isStart) internal pure {
        console.log("\t>>>>> %s output to '%s' <<<<<", isStart ? "Writing" : "Wrote", outputPath);
    }

    function deploymentStep(string memory step, uint256 chainId) internal pure {
        console.log("---------------------- Deploying %s (chainId: %d) ----------------------", step, chainId);
    }

    function functionCall(string memory functionName) internal pure {
        console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~ Calling %s ~~~~~~~~~~~~~~~~~~~~~~~~~~", functionName);
    }

    function functionArg(string memory key, address value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    function functionArg(string memory key, uint256 value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    function functionArg(string memory key, string memory value) internal pure {
        if (bytes(value).length == 0) {
            value = "(none)";
        }
        console.log("\t- %s: %s", key, value);
    }

    function functionArg(string memory key, bytes memory value) internal pure {
        console.log("\t- %s:", key);
        console.logBytes(value);
    }

    function functionArg(string memory key, bytes32 value) internal pure {
        if (value == bytes32(0)) {
            console.log("\t- %s: (none)", key);
            return;
        }

        console.log("\t- %s: %s", key, Strings.toHexString(uint256(value), 32));
    }

    function functionArg(string memory key, bool value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    function functionResult(string memory functionName, bool success, bytes memory err) internal pure {
        if (success) {
            console.log("\n\t>>> Successfully called '%s'", functionName);
            return;
        }

        console.log("\n\t>>> Failed to call '%s'", functionName);
        if (err.length > 0) {
            console.log("\t\t- Error: %s", string(err));
        }
    }

    function deploymentSkipped(string memory name, address contractAddress) internal pure {
        console.log("\n\t>>> Skipped deployment of '%s' (already deployed at '%s')", name, contractAddress);
    }

    function deploymentResult(string memory instanceName, string memory contractName, address contractAddress)
        internal
        pure
    {
        if (keccak256(bytes(instanceName)) == keccak256(bytes(contractName))) {
            console.log("\n\t>>> Deployed '%s' at address '%s'", contractName, contractAddress);
            return;
        }

        console.log("\n\t>>> Deployed '%s' (%s) at address '%s'", instanceName, contractName, contractAddress);
    }

    function separatorHyphen() internal pure {
        console.log("--------------------------------------------------------------------------------");
    }

    function separatorTilda() internal pure {
        console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    }
}
