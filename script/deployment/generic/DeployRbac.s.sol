// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Roles} from "src/Roles.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

/**
 * forge script script/deployment/generic/DeployRbac.s.sol:DeployRbac \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployRbac is Script, DeployBase {
    function run() public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("Roles");
        address created = deployer.create(salt, abi.encodePacked(type(Roles).creationCode, abi.encode(owner)));

        console.log(" Roles(Rbac) deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
