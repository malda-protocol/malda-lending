// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Unit} from "src/Operator/Unit.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

/**
 * forge script script/deployment/generic/DeployUnit.s.sol:DeployUnit \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployUnit is Script, DeployBase {
    function run() public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("Unit");
        address created = deployer.create(salt, abi.encodePacked(type(Unit).creationCode, abi.encode(owner)));

        console.log(" Unit deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
