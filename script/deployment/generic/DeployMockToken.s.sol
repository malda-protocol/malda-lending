// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

/**
 * forge script DeployMockToken  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployMockToken is Script {
    function run() public returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes("ERC20Mock-v1")));

        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);
        
        Deployer deployer = Deployer(payable(0x7DE862D3f944b5BCbE30C43aa5434eE964a31a8C));
        address created = deployer.create(salt, abi.encodePacked(type(ERC20Mock).creationCode, abi.encode("AAA", "AA", 18)));                                          

        console.log(" ERC20Mock deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
