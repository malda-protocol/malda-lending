// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {ConnextBridge} from "src/rebalancer/bridges/ConnextBridge.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployConnextBridge  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address,address)" 0x0,0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployConnextBridge is Script, DeployBase {
    function run(address roles, address connext, address payable _deployer) public returns (address) {
        deployer = Deployer(_deployer);
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt("ConnextBridge");
        address created =
            deployer.create(salt, abi.encodePacked(type(ConnextBridge).creationCode, abi.encode(roles, connext)));

        console.log(" ConnextBridge deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
