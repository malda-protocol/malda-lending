// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AccrossBridge} from "src/rebalancer/bridges/AcrossBridge.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployAcrossBridge  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address,address)" 0x0,0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployAcrossBridge is Script {
    function run(address roles, address spoke, address _deployer) public returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes("AcrossBridge")));
        Deployer deployer = Deployer(payable(_deployer));

        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        address created =
            deployer.create(salt, abi.encodePacked(type(AccrossBridge).creationCode, abi.encode(roles, spoke)));
        vm.stopBroadcast();

        console.log(" AccrossBridge deployed at: %s", created);
        return created;
    }
}
