// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SupportMarket is Script {
    function run(address market) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address operator = vm.envAddress("Operator");
        Operator(operator).supportMarket(market);

        console.log(" Market %s added", market);

        vm.stopBroadcast();
    }
}
