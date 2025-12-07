// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";
import {SetRole} from "../../configuration/SetRole.s.sol";

contract UpdateRoles is DeployBaseRelease {
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
        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Configuring %s ===", network);

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            setRole = new SetRole();
            _setRoles();

            console.log("-------------------- DONE");
        }
    }

    function _setRoles() internal {
        uint256 rolesLength = 10;
        RoleData[] memory rolesData = new RoleData[](rolesLength);

        address target = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
        // address target2 = 0xB819A871d20913839c37f316Dc914b0570bfc0eE; // unused
        address original = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;

        rolesData[0] = RoleData({role: keccak256(abi.encodePacked("CHAINS_MANAGER")), account: target});
        rolesData[1] = RoleData({role: keccak256(abi.encodePacked("PAUSE_MANAGER")), account: target});
        rolesData[2] = RoleData({role: keccak256(abi.encodePacked("PROOF_FORWARDER")), account: target});
        rolesData[3] = RoleData({role: keccak256(abi.encodePacked("GUARDIAN_RESERVE")), account: target});
        rolesData[4] = RoleData({role: keccak256(abi.encodePacked("GUARDIAN_PAUSE")), account: target});
        rolesData[5] = RoleData({role: keccak256(abi.encodePacked("GUARDIAN_BORROW_CAP")), account: target});
        rolesData[6] = RoleData({role: keccak256(abi.encodePacked("GUARDIAN_SUPPLY_CAP")), account: target});
        rolesData[7] = RoleData({role: keccak256(abi.encodePacked("GUARDIAN_ORACLE")), account: target});
        rolesData[8] = RoleData({role: keccak256(abi.encodePacked("GUARDIAN_BRIDGE")), account: target});
        rolesData[9] = RoleData({role: keccak256(abi.encodePacked("REBALANCER_EOA")), account: target});

        // Set roles for new addresses
        for (uint256 i = 0; i < rolesLength; i++) {
            setRole.run(rolesContract, rolesData[i].account, rolesData[i].role, true);
        }

        // Remove roles from original addresses
        for (uint256 i = 0; i < rolesLength; i++) {
            setRole.run(rolesContract, original, rolesData[i].role, false);
        }
    }
}
