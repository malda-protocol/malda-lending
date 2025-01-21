// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";

/**
 * forge script DeployBatchSubmitter  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run(address,address)" 0x0 0x0\
 *     --broadcast
 */
contract DeployBatchSubmitter is Script, DeployBase {
    function run(
        address roles,
        address zkVerifier
    ) public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("BatchSubmitter");
        address created = deployer.create(
            salt,
            abi.encodePacked(
                type(BatchSubmitter).creationCode,
                abi.encode(roles, zkVerifier, owner)
            )
        );

        console.log("BatchSubmitter deployed at:", created);

        vm.stopBroadcast();

        return created;
    }
} 