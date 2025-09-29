// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Operator} from "src/Operator/Operator.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetMinBorrowSize is Script {
   

    //function run() public virtual {
        // address operator = 0x4bbd2B599425026b8A504816D8A043636e2D7Ec7;

        // address[] memory mTokens = new address[](8);
        // mTokens[0] = 0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b; // usdc
        // mTokens[1] = 0x66DfCBf23319D68bdF0cB57797Fcc0A64d2265f8; // usdt
        // mTokens[2] = 0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99; // weth
        // mTokens[3] = 0x0E5ad58f827f53C9F92c71319b77772F2a1FBdb2; // btc
        // mTokens[4] = 0xe79a5f1E2E5619dF1cbb089Db3B11ff9E4dA5aff; // wstEth (linea only)
        // mTokens[5] = 0x867B44af79da71684508c25a1323db3cce5bC23D; // ezEth (linea only)
        // mTokens[6] = 0x301E5481271fD4F4f4C0291F88d7d829c64E2B2b; // weEth (linea only)
        // mTokens[7] = 0xa31963C753f277f7d82d98F56b2C374256925eB7; // wrsEth (linea only)

        // uint256[] memory sizes = new uint256[](8);
        // sizes[0]   = 0.5e6;        // 0.5 USDC (6 decimals)
        // sizes[1]   = 0.5e6;        // 0.5 USDT (6 decimals)
        // sizes[2]   = 0.000125e18;  // 0.000125 ETH
        // sizes[3]   = 0.000005e8;   // 0.000005 BTC (8 decimals)
        // sizes[4] = 0.000125e18;  // 0.000125 wstETH
        // sizes[5]  = 0.0001e18;    // 0.0001 ezETH
        // sizes[6]  = 0.0001e18;    // 0.0001 weETH
        // sizes[7] = 0.0001e18;    // 0.0001 wrsETH

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
