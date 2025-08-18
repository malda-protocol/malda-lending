// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {MockEventEmitter} from "src/MockEventEmitter.sol";

contract DeployEventEmitter is Script {
    function run() public returns (address) {
        Deployer _deployer = Deployer(payable(0x7775C52aeA3780944aE69b389c23c9de325ce29B));


        console.log("Deploying EventEmitter");

 
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address created = address(new MockEventEmitter());
        vm.stopBroadcast();
        
        return created;
    }
}