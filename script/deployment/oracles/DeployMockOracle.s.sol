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
    function run(Deployer deployer) public returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes("MockOracle")));

        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);
        address created = deployer.create(salt, type(OracleMock).creationCode);                                          
        vm.stopBroadcast();
        console.log(" OracleMock deployed at: %s", created);

        console.log(" Setting prices...");
        vm.startBroadcast(key);
        OracleMock(created).setPrice(1e18);
        OracleMock(created).setUnderlyingPrice(1e18);
        vm.stopBroadcast();
        console.log(" Prices updated");
        return created;
    }
}