// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {console} from "forge-std/console.sol";

/// @title Logger
/// @author Malda Protocol
/// @notice Library for logging messages
library Logger {
    /// @notice Logs the config path
    /// @param configPath The path to the config file
    function logConfigPath(string memory configPath) internal pure {
        console.log("\t>>> Using config path '%s'", configPath);
    }

    /// @notice Logs the output path
    /// @param outputPath The path to the output file
    /// @param isStart Whether the output is being started or ended
    function logOutputPath(string memory outputPath, bool isStart) internal pure {
        console.log("\t>>>>> %s output to '%s' <<<<<", isStart ? "Writing" : "Wrote", outputPath);
    }

    /// @notice Logs the deployment step
    /// @param step The name of the deployment step
    /// @param chainId The chain ID
    function deploymentStep(string memory step, uint256 chainId) internal pure {
        console.log("---------------------- Deploying %s (chainId: %d) ----------------------", step, chainId);
    }

    /// @notice Logs the function call
    /// @param functionName The name of the function being called
    function functionCall(string memory functionName) internal pure {
        console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~ Calling %s ~~~~~~~~~~~~~~~~~~~~~~~~~~", functionName);
    }

    /// @notice Logs the function argument
    /// @param key The name of the function argument
    /// @param value The value of the function argument
    function functionArg(string memory key, address value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    /// @notice Logs the function argument
    /// @param key The name of the function argument
    /// @param value The value of the function argument
    function functionArg(string memory key, uint256 value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    /// @notice Logs the function argument
    /// @param key The name of the function argument
    /// @param value The value of the function argument
    function functionArg(string memory key, string memory value) internal pure {
        if (bytes(value).length == 0) {
            value = "(none)";
        }
        console.log("\t- %s: %s", key, value);
    }

    /// @notice Logs the function argument
    /// @param key The name of the function argument
    /// @param value The value of the function argument
    function functionArg(string memory key, bytes memory value) internal pure {
        console.log("\t- %s:", key);
        console.logBytes(value);
    }

    /// @notice Logs the function argument
    /// @param key The name of the function argument
    /// @param value The value of the function argument
    function functionArg(string memory key, bytes32 value) internal pure {
        if (value == bytes32(0)) {
            console.log("\t- %s: (none)", key);
            return;
        }

        console.log("\t- %s: %s", key, Strings.toHexString(uint256(value), 32));
    }

    /// @notice Logs the function argument
    /// @param key The name of the function argument
    /// @param value The value of the function argument
    function functionArg(string memory key, bool value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    /// @notice Logs the function result
    /// @param functionName The name of the function being called
    /// @param success Whether the function call was successful
    /// @param err The error message if the function call failed
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

    /// @notice Logs the deployment skipped
    /// @param name The name of the deployment
    /// @param contractAddress The address of the deployed contract
    function deploymentSkipped(string memory name, address contractAddress) internal pure {
        console.log("\n\t>>> Skipped deployment of '%s' (already deployed at '%s')", name, contractAddress);
    }

    /// @notice Logs the deployment result
    /// @param instanceName The name of the deployment instance
    /// @param contractName The name of the contract
    /// @param contractAddress The address of the deployed contract
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

    /// @notice Logs a separator line
    function separatorHyphen() internal pure {
        console.log("--------------------------------------------------------------------------------");
    }

    /// @notice Logs a separator line
    function separatorTilda() internal pure {
        console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
    }
}
