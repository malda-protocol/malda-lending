// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {EverclearBridgeV2} from "src/rebalancer/bridges/EverclearBridgeV2.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployEverclearBridgeV2  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address,address)" 0x0,0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployEverclearBridgeV2 is Script {
    function run(address roles, address feeAdapter, Deployer deployer) public returns (address) {
        bytes32 salt = getSalt("EverclearBridgeV1.0.5");

        address created = deployer.precompute(salt);
        // Deploy only if not already deployed
        if (created.code.length == 0) {
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            created =
                deployer.create(salt, abi.encodePacked(type(EverclearBridgeV2).creationCode, abi.encode(roles, feeAdapter)));
            vm.stopBroadcast();

            console.log(" EverclearBridgeV2 deployed at: %s", created);
        } else {
            console.log("Using existing EverclearBridgeV2 at: %s", created);
        }
        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
