// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {mTokenConfiguration} from "src/mToken/mTokenConfiguration.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract SetReserveFactor is Script {
    function run(address market, uint256 factor) public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");

        console.log("Setting reserve factor for market", market);

        // Check current admin and reserve factor
        address currentAdmin = mTokenConfiguration(market).admin();
        uint256 currentFactor = mTokenConfiguration(market).reserveFactorMantissa();
        console.log("  Current admin:", currentAdmin);
        console.log("  Current reserve factor:", currentFactor);
        console.log("  Caller address:", vm.addr(key));

        // Skip if already set
        if (currentFactor == factor) {
            console.log("Reserve factor already set to", factor);
            return;
        }

        vm.startBroadcast(key);
        mTokenConfiguration(market).setReserveFactor(factor);
        vm.stopBroadcast();

        console.log("Set reserve factor for market", market);
    }
}
