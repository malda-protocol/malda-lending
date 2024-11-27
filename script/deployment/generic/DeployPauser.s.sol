// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Pauser} from "src/pauser/Pauser.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

/**
 * forge script DeployPauser \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployPauser is Script, DeployBase {
    function run(address roles, address operator) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("Pauser");
        address created =
            deployer.create(salt, abi.encodePacked(type(Pauser).creationCode, abi.encode(roles, operator, owner)));

        console.log(" Pauser deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
