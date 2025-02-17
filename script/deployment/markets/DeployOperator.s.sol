// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {Operator} from "src/Operator/Operator.sol";
import {Unit} from "src/Operator/Unit.sol";

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
contract DeployOperator is Script {
    function run(Deployer deployer, address oracle, address rewardDistributor, address rolesContract, address owner)
        public
        returns (address)
    {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        // Deploy implementation (Operator)
        bytes32 implSalt = getSalt("OperatorImplementation");

        address implementation = deployer.precompute(implSalt);

        if (implementation.code.length > 0) {
            console.log("Operator Implementation already exists at ", implementation);
        } else {
            console.log("Deploying Operator implementation");
            vm.startBroadcast(key);
            implementation = deployer.create(
                implSalt, abi.encodePacked(type(Operator).creationCode, abi.encode(rolesContract, rewardDistributor, owner))
            );
            vm.stopBroadcast();
            console.log("Operator implementation deployed at:", implementation);
        }

        // Deploy proxy (Unit)
        bytes32 proxySalt = getSalt("OperatorProxy");
        address proxy = deployer.precompute(proxySalt);
        
        if (proxy.code.length > 0) {
            console.log("Operator Proxy already exists at ", proxy);
        } else {
            console.log("Deploying Operator proxy (Unit)");
            vm.startBroadcast(key);
            proxy = deployer.create(proxySalt, abi.encodePacked(type(Unit).creationCode, abi.encode(owner)));
            vm.stopBroadcast();
            console.log("Operator proxy (Unit) deployed at:", proxy);

            // Set up the implementation in the proxy
            vm.startBroadcast(key);
            Unit(payable(proxy)).setPendingImplementation(implementation);
            vm.stopBroadcast();
            vm.startBroadcast(key);
            Operator(implementation).become(proxy);
            vm.stopBroadcast();

            vm.startBroadcast(key);
            Operator(proxy).setPriceOracle(oracle);
            vm.stopBroadcast();
            console.log("Price oracle set to:", oracle);

            vm.startBroadcast(key);
            Operator(proxy).setRewardDistributor(rewardDistributor);
            vm.stopBroadcast();
            console.log("Reward distributor set to:", rewardDistributor);
        }

        return proxy;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
