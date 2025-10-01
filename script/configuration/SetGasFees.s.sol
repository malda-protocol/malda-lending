// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DefaultGasHelper} from "src/oracles/gas/DefaultGasHelper.sol";

contract SetGasFees is Script {
    function run() public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");

        address gasHelper = 0xA16e8E9cda2a1F7C3e1E2e5D0D370d8C33c59856; // update when deployed

        uint32[] memory routes = new uint32[](3);
        routes[0] = 8453;
        routes[1] = 59144;
        routes[2] = 1;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 47619047619047; // base
        amounts[1] = 71428571428571; // linea
        amounts[2] = 238095238095238; // eth

        console.log("Set gas destination fees");
        vm.startBroadcast(key);
        for (uint256 j; j < routes.length; j++) {
            DefaultGasHelper(gasHelper).setGasFee(routes[j], amounts[j]);
        }
        vm.stopBroadcast();
        console.log("Gas fees set");
    }
}
