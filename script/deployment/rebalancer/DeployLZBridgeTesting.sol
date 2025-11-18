// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LZUnifiedBridgeTesting} from "src/rebalancer/bridges/deprecated/LZUnifiedBridgeTesting.sol";
import {weEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/weEthOftMessageExecutor.sol";
import {rsEthOftMessageExecutor} from "src/rebalancer/bridges/helpers/rsEthOftMessageExecutor.sol";

contract DeployLZBridgeTesting is Script {
    function run() public {

        
        address roles = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
        address endpoint = 0x1a44076050125825900e736c501f859c50fE728c; 

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        rsEthOftMessageExecutor weEthExecutor = new rsEthOftMessageExecutor();
        //LZUnifiedBridgeTesting lzbridge = new LZUnifiedBridgeTesting(roles, endpoint);
        vm.stopBroadcast();

        console.log(" LZUnifiedBridgeTesting deployed at: %s", address(weEthExecutor));
    }
}