// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";

import {DeployBaseRelease} from "../../../deployers/DeployBaseRelease.sol";
import {SetRole} from "../../../configuration/SetRole.s.sol";

contract UnconfigureRebalancerForMarket is DeployBaseRelease {
    using stdJson for string;

    address internal rolesContract;
    address internal rebalancerContract;
    address internal acrossContract;
    address internal everclearContract;

    SetRole internal setRole;

    address internal marketToRemove = 0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        string memory corePath = "script/deployment/mainnet/output/release-deployed-core-addresses.json";
        string memory jsonContent = vm.readFile(corePath);
        console.logString(jsonContent);
        rolesContract = vm.parseJsonAddress(jsonContent, ".Roles");
        rebalancerContract = vm.parseJsonAddress(jsonContent, ".Rebalancer");
        acrossContract = vm.parseJsonAddress(jsonContent, ".AcrossBridge");
        everclearContract = vm.parseJsonAddress(jsonContent, ".EverclearBridge");
    }

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");

        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Configuring %s ===", network);

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            console.log("Remove from allowed list of tokens");
            address[] memory marketsToRemove = new address[](1);
            marketsToRemove[0] = marketToRemove;
            vm.startBroadcast(key);
            Rebalancer(rebalancerContract).setAllowedTokens(address(acrossContract), marketsToRemove, false);
            Rebalancer(rebalancerContract).setAllowedTokens(address(everclearContract), marketsToRemove, false);
            vm.stopBroadcast();

            console.log("Remove from allowed markets of markets");
            vm.startBroadcast(key);
            Rebalancer(rebalancerContract).setAllowList(marketsToRemove, false);
            Rebalancer(rebalancerContract).setMarketStatus(marketsToRemove, false);
            vm.stopBroadcast();

            console.log("-------------------- DONE");
        }
    }
}
