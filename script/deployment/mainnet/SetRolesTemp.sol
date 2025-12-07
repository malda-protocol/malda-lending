// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";
import {SetRole} from "../../configuration/SetRole.s.sol";

contract SetRolesTemp is DeployBaseRelease {
    using stdJson for string;

    address rolesContract;
    SetRole setRole;

    struct RoleData {
        bytes32 role;
        address account;
    }

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        string memory corePath = "script/deployment/mainnet/output/release-deployed-core-addresses.json";
        string memory jsonContent = vm.readFile(corePath);
        console.logString(jsonContent);
        rolesContract = vm.parseJsonAddress(jsonContent, ".Roles");
    }

    function run() public {
        setRole = new SetRole();
        setRole.run(
            rolesContract,
            0xa493Bb2B6a4374DfeF409255E90bb69a93FE4063,
            keccak256(abi.encodePacked("GUARDIAN_PAUSE")),
            true
        );
    }
}
