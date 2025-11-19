// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployRebalancer  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address)" 0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployRebalancer is Script {
    //function run() public returns (address) {
    function run(address roles, address saveAddress, address admin, Deployer deployer, bytes memory initData) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        bytes32 salt = getSalt("RebalancerV1.0.5");

        // address roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
        // address saveAddress = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
        // Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        // address admin = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;

        address created = deployer.precompute(salt);
        // Deploy only if not already deployed
        if (created.code.length == 0) {
            vm.startBroadcast(key);
            created =
                deployer.create(salt, abi.encodePacked(type(Rebalancer).creationCode, abi.encode(roles, saveAddress, admin, initData)));
            vm.stopBroadcast();
            console.log("Rebalancer deployed at:", created);
        } else {
            console.log("Using existing Rebalancer at: %s", created);
        }

        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
