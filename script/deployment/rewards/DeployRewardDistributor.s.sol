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
    function run(Deployer deployer) public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("RewardDistributor");
        address created = deployer.create(salt, type(RewardDistributor).creationCode);
        RewardDistributor(created).initialize(owner);

        console.log(" RewardDistributor deployed (and initialized) at: %s", created);

        vm.stopBroadcast();

        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
