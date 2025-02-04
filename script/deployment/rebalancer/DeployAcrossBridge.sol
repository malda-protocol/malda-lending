// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
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
contract DeployAcrossBridge is Script, DeployBase {
    function run(address roles, address spoke, address _deployer) public returns (address) {
        deployer = Deployer(_deployer);
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt("AccrossBridge");
        address created =
            deployer.create(salt, abi.encodePacked(type(AccrossBridge).creationCode, abi.encode(roles, spoke)));

        console.log(" AccrossBridge deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
