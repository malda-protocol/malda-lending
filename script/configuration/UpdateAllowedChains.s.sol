// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {mErc20Host} from "../../src/mToken/host/mErc20Host.sol";
import {Script, console} from "forge-std/Script.sol";

contract UpdateAllowedChains is Script {
    function run(address market, uint32 chainId, bool isAllowed) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        vm.startBroadcast(key);
        mErc20Host(market).updateAllowedChain(chainId, isAllowed);
        vm.stopBroadcast();

        console.log("Allowed chain updated for market %s", market);
    }
}
