// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LZBridge} from "src/rebalancer/bridges/LZBridge.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployLZBridge  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address)" 0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployLZBridge is Script {
    function run(address roles, address _deployer) public returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes("LZBridge")));
        Deployer deployer = Deployer(payable(_deployer));

        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        address created = deployer.create(salt, abi.encodePacked(type(LZBridge).creationCode, abi.encode(roles)));
        vm.stopBroadcast();

        console.log(" LZBridge deployed at: %s", created);
        return created;
    }
}
