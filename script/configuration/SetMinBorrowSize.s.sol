// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetMinBorrowSize is Script {
    function run(address operator, address market, uint256 size) public virtual {
        uint256 key = vm.envUint("PRIVATE_KEY");

        address[] memory mTokens = new address[](1);
        uint256[] memory sizes = new uint256[](1);
        mTokens[0] = market;
        sizes[0] = size;

        console.log("Setting min borrow size for market", market);

        vm.startBroadcast(key);
        Operator(operator).setBorrowSizeMin(mTokens, sizes);
        vm.stopBroadcast();

        console.log("Min borrow set for market", market);
    }
}
