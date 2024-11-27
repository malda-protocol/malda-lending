// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetBorrowCap is Script {
    function run(address oracle) public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address operator = vm.envAddress("Operator");
        Operator(operator).setPriceOracle(oracle);

        console.log(" Updated price oracle on operator: %s", oracle);

        vm.stopBroadcast();
    }
}
