// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {MockEventEmitter} from "src/MockEventEmitter.sol";

contract DeployEventEmitter is Script {
    function run() public returns (address) {
        console.log("Deploying EventEmitter");

 
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address created = address(new MockEventEmitter());
        vm.stopBroadcast();
        
        return created;
    }
}