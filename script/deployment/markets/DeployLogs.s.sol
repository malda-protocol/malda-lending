// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {mTokenLogs} from "src/mToken/mTokenLogs.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

/**
 * forge script script/deployment/markets/DeployLogs.s.sol:DeployLogs  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run(address)" 0x0 \
 *     --broadcast
 */
contract DeployLogs is Script, DeployBase {
    function run(address roles) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt("mTokenLogs");
        address created = deployer.create(salt, abi.encodePacked(type(mTokenLogs).creationCode, abi.encode(roles)));
        console.log(" Logs deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
