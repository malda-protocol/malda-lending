// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {RewardDistributor} from "src/rewards/RewardDistributor.sol";

import {Script, console} from "forge-std/Script.sol";

contract SetOperatorForRewards is Script {
    // RewardDistributor(created).setOperator(operator);

    function run(address rewards) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address operator = vm.envAddress("Operator");
        RewardDistributor(rewards).setOperator(operator);

        console.log(" Operator set for reward distributor %s", rewards);

        vm.stopBroadcast();
    }
}
