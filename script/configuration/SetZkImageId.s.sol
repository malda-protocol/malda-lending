// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {BatchSubmitter} from "src/mToken/BatchSubmitter.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetZkImageId is Script {
    function run(address[] memory marketAddresses, address batchSubmitter, bytes32 imageId) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        console.log("Setting ZK image ID for BatchSubmitter %s", batchSubmitter);

        if (BatchSubmitter(batchSubmitter).imageId() == imageId) {
            console.log("ZK image ID already set");
            return;
        }

        vm.startBroadcast(key);
        BatchSubmitter(batchSubmitter).setImageId(imageId);
        vm.stopBroadcast();

        console.log("ZK image ID set for BatchSubmitter %s", batchSubmitter);

        for (uint256 i = 0; i < marketAddresses.length; i++) {
            console.log("Setting ZK image ID for market %s", marketAddresses[i]);

            if (mErc20Host(marketAddresses[i]).imageId() == imageId) {
                console.log("ZK image ID already set");
            } else {
                vm.startBroadcast(key);
                mErc20Host(marketAddresses[i]).setImageId(imageId);
                vm.stopBroadcast();
            }

            console.log("ZK image ID set for market %s", marketAddresses[i]);
        }
    }
}
