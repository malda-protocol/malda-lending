// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Strings} from "@oz/utils/Strings.sol";

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {DeployerUtil} from "script/utils/DeployerUtil.sol";

library Logger {
    /// @notice Prints the output path to the console
    /// @param configPath The path to the config file
    function logConfigPath(Vm vm, string memory configPath) internal view {
        console.log("\t>>> Using config path '%s'\n", DeployerUtil.buildAbsolutePath(vm, configPath));
    }

    /// @notice Prints the output path to the console
    /// @param outputPath The path to the output file
    function logOutputPath(Vm vm, string memory outputPath, bool isStart) internal view {
        console.log(
            "\t>>>>> %s output to '%s' <<<<<\n",
            isStart ? "Writing" : "Wrote",
            DeployerUtil.buildAbsolutePath(vm, outputPath)
        );
    }

    /// @notice Prints a deployment step to the console
    /// @param step The name of the deployment step
    function deploymentStep(string memory step, uint256 chainId) internal pure {
        console.log("-------------------------- Deploying %s (chainId: %d) --------------------------", step, chainId);
    }

    /// @notice Prints a function call to the console
    /// @param functionName The name of the function being called
    function functionCall(string memory functionName) internal pure {
        console.log("~~~~~~~~~~~~~~~~~~~~~~~~~~ Calling %s ~~~~~~~~~~~~~~~~~~~~~~~~~~", functionName);
    }

    /// @notice Prints the setting of roles and their capabilities to the console
    function setRolesAndCapabilities() internal pure {
        console.log("\n\t>>> Setting roles and their capabilities");
    }

    /// @notice Prints the deployer address to the console
    /// @param deployerAddress The address of the deployer
    function logDeployerAddress(address deployerAddress) internal pure {
        console.log(
            "\n\t>>> Deploying as '%s' (also used as 'initialOwner'/'rolesAuthorityOwner' in configs)\n",
            deployerAddress
        );
    }

    /// @notice Prints the no config path message to the console
    function noConfigPath() internal pure {
        console.log("\t>>> No config path provided, using default config path");
    }

    /// @notice Prints the no output path message to the console
    function noOutputPath() internal pure {
        console.log("\t>>> No output path provided, using default output path");
    }

    /// @notice Prints the updating of the owner to the console
    /// @param target The address of the target
    /// @param newOwner The new owner
    function updateOwner(address target, address newOwner, bool isTwoStep) internal pure {
        console.log(
            "\n\t>>> Updating the owner of '%s' to '%s'%s",
            target,
            newOwner,
            isTwoStep ? " (~~~ Transfer is two-step, make sure to accept the ownership! ~~~)" : ""
        );
    }

    /// @notice Prints a function argument to the console
    /// @param key The name of the argument
    /// @param value The value of the argument
    function functionArg(string memory key, address value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    /// @notice Prints a function argument to the console
    /// @param key The name of the argument
    /// @param value The value of the argument
    function functionArg(string memory key, bytes32 value) internal pure {
        string memory valueStr = Strings.toHexString(uint256(value), 32);

        if (value == bytes32(0)) valueStr = "(none)";
        console.log("\t- %s: %s", key, valueStr);
    }

    /// @notice Prints a function argument to the console
    /// @param key The name of the argument
    /// @param value The value of the argument
    function functionArg(string memory key, string memory value) internal pure {
        if (bytes(value).length == 0) value = "(none)";
        console.log("\t- %s: %s", key, value);
    }

    function functionArg(string memory key, bytes memory value) internal pure {
        console.log("\t- %s:", key);
        console.logBytes(value);
    }

    /// @notice Prints a function argument to the console
    /// @param key The name of the argument
    /// @param value The value of the argument
    function functionArg(string memory key, uint256 value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    /// @notice Prints a function argument to the console
    /// @param key The name of the argument
    /// @param value The value of the argument
    function functionArg(string memory key, bool value) internal pure {
        console.log("\t- %s: %s", key, value);
    }

    /// @notice Prints a role to the console
    /// @param target The address of the target
    /// @param roleName The name of the role
    /// @param roleId The id of the role
    /// @param isGranted Whether the role is granted or revoked (true = grant, false = revoke)
    function role(address target, string memory roleName, uint8 roleId, bool isGranted) internal pure {
        string memory messageStart = string.concat(isGranted ? "Granting" : "Revoking", " '", roleName, "' role");
        console.log("\t\t- %s (id=%d) to '%s'", messageStart, uint256(roleId), target);
    }

    /// @notice Prints a deployment result to the console
    /// @param name The name of the contract, e.g. "OracleRegistryTimelock"
    /// @param contractAddress The address of the contract
    function deploymentSkipped(string memory name, address contractAddress) internal pure {
        console.log(">>> Skipped deployment of '%s' (already deployed at address '%s')", name, contractAddress);
    }

    /// @notice Prints deployed contract address to the console
    /// @param instanceName The name of the contract instance, e.g. "OracleRegistryTimelock"
    /// @param contractName The name of the contract, e.g. "OracleRegistry"
    /// @param contractAddress The address of the contract
    function deploymentResult(string memory instanceName, string memory contractName, address contractAddress)
        internal
        pure
    {
        if (keccak256(bytes(instanceName)) == keccak256(bytes(contractName))) {
            // Instance and contract names are the same (e.g. "OracleRegistry") - print only the contract name
            console.log("\n\t>>> Deployed '%s' at address '%s'", contractName, contractAddress);
        } else {
            // Instance and contract names are different (e.g. "OracleRegistryTimelock" and "OracleRegistry") - print
            // both to make it clear
            console.log("\n\t>>> Deployed '%s' (%s) at address '%s'", instanceName, contractName, contractAddress);
        }
    }

    /// @notice Prints a function call result to the console
    /// @param functionName The name of the function
    /// @param success Whether the function call was successful
    /// @param err The error message
    function functionResult(string memory functionName, bool success, bytes memory err) internal pure {
        if (success) {
            console.log("\n\t>>> Successfully called '%s'", functionName);
        } else {
            console.log("\n\t>>> Failed to call '%s'", functionName);
            console.log("\t\t- Error: %s", string(err));
        }
    }

    /// @notice Prints a sleep message to the console
    /// @param timeInSeconds The number of seconds to sleep
    function sleep(uint256 timeInSeconds) internal pure {
        console.log("\t>>> Sleeping for %d seconds...\n", timeInSeconds);
    }

    ////////////////////////////////////////////////////////////
    //                       Separators                       //
    ////////////////////////////////////////////////////////////

    /// @notice Prints a separator line to the console
    function separatorHyphen() internal pure {
        console.log(
            "-----------------------------------------------------------------------------------------------------\n"
        );
    }

    /// @notice Prints a separator line to the console
    function separatorTilda() internal pure {
        console.log(
            "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"
        );
    }
}
