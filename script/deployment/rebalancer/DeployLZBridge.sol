// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
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
contract DeployLZBridge is Script, DeployBase {
    function run(address roles, address payable _deployer) public returns (address) {
        deployer = Deployer(_deployer);
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt("LZBridge");
        address created = deployer.create(salt, abi.encodePacked(type(LZBridge).creationCode, abi.encode(roles)));

        console.log(" LZBridge deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
