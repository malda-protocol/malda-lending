// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetBorrowCap is Script {
    function run(address operator, address market, uint256 cap) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        address[] memory mTokens = new address[](1);
        uint256[] memory caps = new uint256[](1);
        mTokens[0] = market;
        caps[0] = cap;

        vm.startBroadcast(key);
        Operator(operator).setMarketBorrowCaps(mTokens, caps);
        vm.stopBroadcast();

        console.log("Borrow cap set for market %s", market);
    }
}
