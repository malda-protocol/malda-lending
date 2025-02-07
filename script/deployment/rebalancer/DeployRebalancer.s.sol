// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployRebalancer  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address)" 0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployRebalancer is Script {
    function run(address roles, address _deployer) public returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes("Rebalancer")));
        Deployer deployer = Deployer(payable(_deployer));

        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        address created = deployer.create(salt, abi.encodePacked(type(Rebalancer).creationCode, abi.encode(roles)));
        vm.stopBroadcast();

        console.log(" Rebalancer deployed at: %s", created);
        return created;
    }
}
