// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetCollateralFactor is Script {
    function run(address market, uint256 factor) public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address operator = vm.envAddress("Operator");
        Operator(operator).setCollateralFactor(market, factor);

        console.log(" Set collateral factor %s for market %s", factor, market);

        vm.stopBroadcast();
    }
}
