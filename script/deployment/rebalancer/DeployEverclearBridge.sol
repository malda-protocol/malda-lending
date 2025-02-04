// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
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
contract DeployEverclearBridge is Script, DeployBase {
    function run(address roles, address spoke, address payable _deployer) public returns (address) {
        deployer = Deployer(_deployer);
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt("EverclearBridge");
        address created =
            deployer.create(salt, abi.encodePacked(type(EverclearBridge).creationCode, abi.encode(roles, spoke)));

        console.log(" EverclearBridge deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
