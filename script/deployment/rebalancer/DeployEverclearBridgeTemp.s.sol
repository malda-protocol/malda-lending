// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {EverclearBridge} from "src/rebalancer/bridges/EverclearBridge.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployEverclearBridge  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address,address)" 0x0,0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployEverclearBridgeTemp is Script {
    function run() public returns (address) {
        address roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
        address feeAdapter = 0x15a7cA97D1ed168fB34a4055CEFa2E2f9Bdb6C75;
        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        bytes32 salt = getSalt("EverclearV1.0.5");

        address created = deployer.precompute(salt);
        // Deploy only if not already deployed
        if (created.code.length == 0) {
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            created = deployer.create(
                salt, abi.encodePacked(type(EverclearBridge).creationCode, abi.encode(roles, feeAdapter))
            );
            vm.stopBroadcast();

            console.log(" EverclearBridge deployed at: %s", created);
        } else {
            console.log("Using existing EverclearBridge at: %s", created);
        }
        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
            );
    }
}
