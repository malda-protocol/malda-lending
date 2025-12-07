// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";

contract CancelTx is DeployBaseRelease {
    address constant RECEIVER = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);
        (bool success,) = RECEIVER.call{value: 0}("");
        require(success, "Tx failed");
        vm.stopBroadcast();
    }
}
