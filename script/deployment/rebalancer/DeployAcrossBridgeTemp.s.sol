// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AccrossBridge} from "src/rebalancer/bridges/AcrossBridge.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployAcrossBridgeTemp  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address,address)" 0x0,0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployAcrossBridgeTemp is Script {
    //function run(address roles, address spoke, address rebalancer, Deployer deployer) public returns (address) {
    function run() public returns (address) {
        bytes32 salt = getSalt("AcrossBridgeV1.0.5-patch2");

        address roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
        address spoke = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
        address rebalancer = 0x43090Bd0499936f0F66DaCd870aa84fFdc92EDB1;
        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));

        address created = deployer.precompute(salt);
        // Deploy only if not already deployed
        if (created.code.length == 0) {
            vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
            created = deployer.create(
                salt, abi.encodePacked(type(AccrossBridge).creationCode, abi.encode(roles, spoke, rebalancer))
            );
            vm.stopBroadcast();
            console.log(" AccrossBridge deployed at: %s", created);
        } else {
            console.log("Using existing AccrossBridge at: %s", created);
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
