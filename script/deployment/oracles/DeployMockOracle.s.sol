// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {OracleMock} from "test/mocks/OracleMock.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployMockOracle  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployMockOracle is Script {
    function run() public returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes("MockOracle-v1")));

        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);
        Deployer deployer = Deployer(payable(0x7DE862D3f944b5BCbE30C43aa5434eE964a31a8C));

        address created = deployer.create(salt, type(OracleMock).creationCode);                                          

        console.log(" OracleMock deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
