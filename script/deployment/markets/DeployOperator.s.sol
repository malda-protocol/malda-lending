// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Unit} from "src/Operator/Unit.sol";

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

        // Deploy implementation (Operator)
        bytes32 implSalt = getSalt("OperatorImplementation");
        address implementation =
            deployer.create(implSalt, abi.encodePacked(type(Operator).creationCode, abi.encode(roles, rewards, owner)));
        console.log("Operator implementation deployed at:", implementation);

        // Deploy proxy (Unit)
        bytes32 proxySalt = getSalt("OperatorProxy");
        address proxy = deployer.create(proxySalt, abi.encodePacked(type(Unit).creationCode, abi.encode(owner)));
        console.log("Operator proxy (Unit) deployed at:", proxy);

        // Set up the implementation in the proxy
        Unit(payable(proxy)).setPendingImplementation(implementation);
        Operator(implementation).become(proxy);

        Operator(proxy).setPriceOracle(oracle);
        console.log("Price oracle set to:", oracle);

        vm.stopBroadcast();

        return proxy;
    }
}
