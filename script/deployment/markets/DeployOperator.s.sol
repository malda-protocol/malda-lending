// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

/**
 * forge script script/deployment/markets/DeployOperator.s.sol:DeployOperator  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run(address,address,address)" 0x0,0x0,0x0 \
 *     --broadcast
 */
contract DeployOperator is Script, DeployBase {
    function run(address oracle, address rewards, address roles) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("Operator");
        address created =
            deployer.create(salt, abi.encodePacked(type(Operator).creationCode, abi.encode(roles, rewards, owner)));
        Operator(created).setPriceOracle(oracle);

        console.log(" Operator deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
