// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";
import {SetWhitelistEnabled} from "../../configuration/SetWhitelistEnabled.s.sol";
import {SetWhitelistedUsersOnGateway} from "../../configuration/SetWhitelistedUsersOnGateway.s.sol";

contract SetWhitelist is DeployBaseRelease {
    using stdJson for string;

    address[] marketList;
    address operator;

    SetWhitelistEnabled setWhitelistEnabled;
    SetWhitelistedUsersOnGateway setWhitelistEnabledOnExtension;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        string memory marketsOutputPath = "script/deployment/mainnet/output/release-deployed-market-addresses.json";
        string memory rawMarketJson = vm.readFile(marketsOutputPath);
        uint256 length = 8;
        marketList = new address[](length);
        console.log("Markets: ");
        for (uint256 i; i < length; ++i) {
            string memory base = string.concat("[", vm.toString(i), "]");

            address marketAddr = vm.parseJsonAddress(rawMarketJson, string.concat(base, ".address"));
            if (marketAddr != address(0)) {
                marketList[i] = marketAddr;
            }
        }
        console.log("Registered no of markets:", marketList.length);
        for (uint256 i; i < marketList.length; ++i) {
            console.log(" - market: ", marketList[i]);
        }

        string memory corePath = "script/deployment/mainnet/output/release-deployed-core-addresses.json";
        string memory jsonContent = vm.readFile(corePath);
        console.logString(jsonContent);
        operator = vm.parseJsonAddress(jsonContent, ".Operator");
    }

    function run() public {
        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Configuring %s ===", network);

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            if (configs[network].isHost) {
                setWhitelistEnabled = new SetWhitelistEnabled();
                _configure();
            } else {
                console.log("Configuring EXTENSION");
                setWhitelistEnabledOnExtension = new SetWhitelistedUsersOnGateway();
                setWhitelistEnabledOnExtension.run(marketList);
            }

            console.log("-------------------- DONE");
        }
    }

    function _configure() internal {
        console.log("Configuring whitelist", address(operator));
        setWhitelistEnabled.run(operator);
    }
}
