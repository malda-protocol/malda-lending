// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployRewardDistributor  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployRewardDistributor is Script {
    function run(Deployer deployer, address owner) public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        bytes32 salt = getSalt("RewardDistributor");

        console.log("Deploying RewardDistributor");
        address created = deployer.precompute(salt);
        if (created.code.length > 0) {
            console.log("RewardDistributor already deployed at: %s", created);
        } else {
            vm.startBroadcast(key);
            created = deployer.create(salt, type(RewardDistributor).creationCode);
            vm.stopBroadcast();
            console.log("RewardDistributor deployed at: %s", created);
                
            console.log("Initializing RewardDistributor");

            vm.startBroadcast(key);
            RewardDistributor(created).initialize(owner);
            vm.stopBroadcast();

            console.log("RewardDistributor initialized at: %s", created);
        }

        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
