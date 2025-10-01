// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";

interface IGasFeeExtension {
    function setGasFee(uint256 amount) external;
}
contract SetGasFeesOnExtension is Script {
    function run() public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");


        uint256 amount = 71428571428571; //linea
        address[] memory markets = new address[](4);
        markets[0] = 0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b;
        markets[1] = 0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99;
        markets[2] = 0x66DfCBf23319D68bdF0cB57797Fcc0A64d2265f8;
        markets[3] = 0x0E5ad58f827f53C9F92c71319b77772F2a1FBdb2;

        console.log("Set gas destination fees");
        vm.startBroadcast(key);
        for (uint256 i; i < markets.length; ++i) {
            IGasFeeExtension(markets[i]).setGasFee(amount);
        }
        vm.stopBroadcast();
        console.log("Gas fees set");
    }
}
