// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Blacklister} from "src/blacklister/Blacklister.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * forge script DeployBlacklister  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run(address,address)" 0x0 0x0\
 *     --broadcast
 */
contract DeployBlacklister is Script {
    //function run() public returns (address) {
    //    Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
    //    address roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
    //    address owner = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
    function run(Deployer deployer, address roles, address owner) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");

        bytes32 implSalt = _getSalt("BlacklisterImplementationV1.0.0");
        address implementation = deployer.precompute(implSalt);
        if (implementation.code.length > 0) {
            console.log("Blacklister implementation already deployed at:", implementation);
        } else {
            vm.startBroadcast(key);
            implementation = deployer.create(implSalt, abi.encodePacked(type(Blacklister).creationCode));
            vm.stopBroadcast();
            console.log("Blacklister implementation deployed at:", implementation);
        }


        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, owner, roles);
        // Deploy proxy
        bytes32 proxySalt = _getSalt("BlacklisterProxyV1.0.0");
        address blacklisterAddress = deployer.precompute(proxySalt);
        if (blacklisterAddress.code.length > 0) {
            console.log("Blacklister proxy already deployed at:", blacklisterAddress);
        } else {
            vm.startBroadcast(key);
            blacklisterAddress = deployer.create(
                proxySalt,
                abi.encodePacked(
                    type(TransparentUpgradeableProxy).creationCode, abi.encode(implementation, owner, initData)
                )
            );
            vm.stopBroadcast();
            console.log("Blacklister proxy deployed at:", blacklisterAddress);

        }

        return blacklisterAddress;
    }

    function _getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}