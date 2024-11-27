// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

/**
 * forge script DeployRewardDistributor  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployRewardDistributor is Script, DeployBase {
    function run() public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("RewardDistributor");
        address created = deployer.create(salt, type(RewardDistributor).creationCode);
        RewardDistributor(created).initialize(owner);

        console.log(" RewardDistributor deployed (and initialized) at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
