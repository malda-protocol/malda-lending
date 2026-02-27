// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {JsonReader} from "script/utils/JsonReader.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";

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

    /// @notice Updates the roles address of the script
    /// @param script The deploy script instance
    /// @param roles The roles to set
    /// @return The updated deploy script instance
    function withRoles(ScriptBase script, address roles) internal returns (ScriptBase) {
        script.setConfigOverride("roles", roles);
        return script;
    }

    /// @notice Updates the roles contract of the script
    /// @param script The deploy script instance
    /// @param rolesContract The roles contract to set
    /// @return The updated deploy script instance
    function withRolesContract(ScriptBase script, address rolesContract) internal returns (ScriptBase) {
        script.setConfigOverride("rolesContract", rolesContract);
        return script;
    }

    /// @notice Updates the zk verifier of the script
    /// @param script The deploy script instance
    /// @param zkVerifier The zk verifier to set
    /// @return The updated deploy script instance
    function withZkVerifier(ScriptBase script, address zkVerifier) internal returns (ScriptBase) {
        script.setConfigOverride("zkVerifier", zkVerifier);
        return script;
    }

    /// @notice Updates the blacklister of the script
    /// @param script The deploy script instance
    /// @param blacklister The blacklister to set
    /// @return The updated deploy script instance
    function withBlacklister(ScriptBase script, address blacklister) internal returns (ScriptBase) {
        script.setConfigOverride("blacklister", blacklister);
        return script;
    }

    /// @notice Updates the blacklist operator of the script
    /// @param script The deploy script instance
    /// @param blacklistOperator The blacklist operator to set
    /// @return The updated deploy script instance
    function withBlacklistOperator(ScriptBase script, address blacklistOperator) internal returns (ScriptBase) {
        script.setConfigOverride("blacklistOperator", blacklistOperator);
        return script;
    }

    /// @notice Updates the operator of the script
    /// @param script The deploy script instance
    /// @param operator The operator to set
    /// @return The updated deploy script instance
    function withOperator(ScriptBase script, address operator) internal returns (ScriptBase) {
        script.setConfigOverride("operator", operator);
        return script;
    }

    /// @notice Updates the oracle of the script
    /// @param script The deploy script instance
    /// @param oracle The oracle to set
    /// @return The updated deploy script instance
    function withOracle(ScriptBase script, address oracle) internal returns (ScriptBase) {
        script.setConfigOverride("oracle", oracle);
        return script;
    }

    /// @notice Updates the reward distributor of the script
    /// @param script The deploy script instance
    /// @param rewardDistributor The reward distributor to set
    /// @return The updated deploy script instance
    function withRewardDistributor(ScriptBase script, address rewardDistributor) internal returns (ScriptBase) {
        script.setConfigOverride("rewardDistributor", rewardDistributor);
        return script;
    }

    /// @notice Updates the rebalancer of the script
    /// @param script The deploy script instance
    /// @param rebalancer The rebalancer to set
    /// @return The updated deploy script instance
    function withRebalancer(ScriptBase script, address rebalancer) internal returns (ScriptBase) {
        script.setConfigOverride("rebalancer", rebalancer);
        return script;
    }

    /// @notice Updates the interest model of the script
    /// @param script The deploy script instance
    /// @param interestModel The interest model to set
    /// @return The updated deploy script instance
    function withInterestModel(ScriptBase script, address interestModel) internal returns (ScriptBase) {
        script.setConfigOverride("interestModel", interestModel);
        return script;
    }

    /// @notice Updates the market of the script
    /// @param script The deploy script instance
    /// @param market The market to set
    /// @return The updated deploy script instance
    function withMarket(ScriptBase script, address market) internal returns (ScriptBase) {
        script.setConfigOverride("market", market);
        return script;
    }

    /// @notice Updates the gas helper of the script
    /// @param script The deploy script instance
    /// @param gasHelper The gas helper to set
    /// @return The updated deploy script instance
    function withGasHelper(ScriptBase script, address gasHelper) internal returns (ScriptBase) {
        script.setConfigOverride("gasHelper", gasHelper);
        return script;
    }

    /// @notice Updates the receiver of the script
    /// @param script The deploy script instance
    /// @param receiver The receiver to set
    /// @return The updated deploy script instance
    function withReceiver(ScriptBase script, address receiver) internal returns (ScriptBase) {
        script.setConfigOverride("receiver", receiver);
        return script;
    }

    /// @notice Builds the absolute path to the output JSON file
    /// @param vm The VM instance
    /// @param outputPath The path to the output JSON file
    /// @return absolutePath The absolute path to the output JSON file
    function buildAbsolutePath(Vm vm, string memory outputPath) internal view returns (string memory) {
        return string.concat(vm.projectRoot(), "/", outputPath);
    }
}
