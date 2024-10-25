// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/Script.sol";
import {Deployer} from "../../src/utils/Deployer.sol";
import {DeployBase} from "./DeployBase.sol";

contract DeployerScript is DeployBase {
    Deployer deployer;

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");

        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOYER_SALT"))));

        vm.startBroadcast(key);

        address deployedAddress = _deployCreate2(salt, type(Deployer).creationCode, "");
        console.log("Deployer contract deployed at: %s", deployedAddress);

        vm.stopBroadcast();
    }
}
