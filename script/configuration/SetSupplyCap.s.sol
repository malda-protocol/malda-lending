// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetSupplyCap is Script {
    function run(address operator, address market, uint256 cap) public {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address[] memory mTokens = new address[](1);
        uint256[] memory caps = new uint256[](1);
        mTokens[0] = market;
        caps[0] = cap;

        Operator(operator).setMarketSupplyCaps(mTokens, caps);

        console.log(" Supply cap set for market %s", market);

        vm.stopBroadcast();
    }
}
