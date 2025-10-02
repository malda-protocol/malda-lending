// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Operator} from "src/Operator/Operator.sol";
import {Roles} from "src/Roles.sol";
import {Pauser} from "src/pauser/Pauser.sol";

import {
    DeployConfig,
    MarketRelease,
    Role,
    InterestConfig,
    OracleConfigRelease,
    OracleFeed
} from "../../deployers/Types.sol";

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

        string memory marketsOutputPath = "script/deployment/mainnet/output/release-deployed-market-addresses.json";
        string memory rawMarketJson = vm.readFile(marketsOutputPath);

        string memory corePath = "script/deployment/mainnet/output/release-deployed-core-addresses.json";
        string memory jsonContent = vm.readFile(corePath);
        console.logString(jsonContent);
        rolesContract = vm.parseJsonAddress(jsonContent, ".Roles");
    }

    function run() public {
        setRole = new SetRole();
        setRole.run(rolesContract, 0xa493Bb2B6a4374DfeF409255E90bb69a93FE4063, keccak256(abi.encodePacked("GUARDIAN_PAUSE")), true);

    }
}
