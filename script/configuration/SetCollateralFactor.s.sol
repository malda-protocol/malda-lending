// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetCollateralFactor is Script {
    function run(address operator, address market, uint256 factor) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        console.log("Setting collateral factor");

        if (Operator(operator).markets(market).collateralFactorMantissa == factor) {
            console.log("Collateral factor already set");
            return;
        }

        vm.startBroadcast(key);
        Operator(operator).setCollateralFactor(market, factor);
        vm.stopBroadcast();

        console.log("Set collateral factor:", factor, "for market:", market);
    }
}
