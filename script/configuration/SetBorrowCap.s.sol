// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetBorrowCap is Script {
    function run(address market, uint256 cap) public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address[] memory mTokens = new address[](1);
        uint256[] memory caps = new uint256[](1);
        mTokens[0] = market;
        caps[0] = cap;

        address operator = vm.envAddress("Operator");
        Operator(operator).setMarketBorrowCaps(mTokens, caps);

        console.log(" Borrow cap set for market %s", market);

        vm.stopBroadcast();
    }
}
