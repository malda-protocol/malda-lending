// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Roles} from "src/Roles.sol";
import {Script, console} from "forge-std/Script.sol";

contract SetRoles is Script {
    function run(address receiver, bytes32 role, bool status) public virtual {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address roles = vm.envAddress("Rbac");
        Roles(roles).allowFor(receiver, role, status);

        if (status) {
            console.log(" Added role for %s", receiver);
        } else {
            console.log(" Removed role for %s", receiver);
        }

        vm.stopBroadcast();
    }
}
