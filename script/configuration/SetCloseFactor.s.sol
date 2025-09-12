// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetCloseFactor is Script {
    function run(address operator, uint256 factor) public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");

        console.log("Setting close factor on Operator");

        vm.startBroadcast(key);
        Operator(operator).setCloseFactor(factor);
        vm.stopBroadcast();

        console.log("Set close factor on Operator");
    }
}