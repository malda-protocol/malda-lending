// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {ZkVerifierImageRegistry} from "src/verifier/ZkVerifierImageRegistry.sol";

/**
 * forge script DeployImageRegistry  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployImageRegistry is Script, DeployBase {
    function run() public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("ZkVerifierImageRegistry");
        address created =
            deployer.create(salt, abi.encodePacked(type(ZkVerifierImageRegistry).creationCode, abi.encode(owner)));

        console.log(" ZkVerifierImageRegistry deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
