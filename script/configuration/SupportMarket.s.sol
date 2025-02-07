// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SupportMarket is Script {
    function run(address operator, address market) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        console.log("Supporting market");

        vm.startBroadcast(key);
        Operator(operator).supportMarket(market);
        vm.stopBroadcast();

        console.log("Supported market:", market);
    }
}
