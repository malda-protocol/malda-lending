// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {Migrator} from "src/migration/Migrator.sol";
import {Deployer} from "src/utils/Deployer.sol";

contract DeployMigrator is Script {
    function run() public returns (address) {
        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        uint256 key = vm.envUint("PRIVATE_KEY");

        bytes32 salt = getSalt("MigratorV1.0.5");

        console.log("Deploying Migrator");

        address created = deployer.precompute(salt);
        address operator = 0x4bbd2B599425026b8A504816D8A043636e2D7Ec7;

        // Deploy only if not already deployed
        if (created.code.length == 0) {
            vm.startBroadcast(key);
            created = 
                deployer.create(salt, abi.encodePacked(type(Migrator).creationCode, abi.encode(operator)));
            vm.stopBroadcast();
            console.log("Migrator deployed at: %s", created);
        } else {
            console.log("Using existing Migrator at: %s", created);
        }

        return created;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
