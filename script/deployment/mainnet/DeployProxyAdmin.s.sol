// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployNewProxyAdmin is Script {
    address constant NEW_OWNER = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;

    address constant EXISTING_PROXY = 0x0000000000000000000000000000000000000000;

    function run() external {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        console.log("Deploying new ProxyAdmin...");
        ProxyAdmin newAdmin = new ProxyAdmin(0xB819A871d20913839c37f316Dc914b0570bfc0eE);


        console.log(" New ProxyAdmin deployed at:", address(newAdmin));

        // ================================================================
        // OPTIONAL: Reassign admin of an existing proxy
        // Uncomment if you want to do it in the same run
        // ================================================================
        /*
        console.log("Changing admin of proxy to new ProxyAdmin...");
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(EXISTING_PROXY);
        proxy.changeAdmin(address(newAdmin));
        console.log("Proxy admin successfully updated!");
        */

        vm.stopBroadcast();
    }
}
