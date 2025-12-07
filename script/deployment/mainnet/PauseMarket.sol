// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Pauser} from "src/pauser/Pauser.sol";
import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";

contract PauseMarket is DeployBaseRelease {
    using stdJson for string;

    address internal constant RECEIVER = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
    address internal constant MARKET_TO_PAUSE = 0xe79a5f1E2E5619dF1cbb089Db3B11ff9E4dA5aff;

    address internal pauserContract;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        string memory corePath = "script/deployment/mainnet/output/release-deployed-core-addresses.json";
        string memory jsonContent = vm.readFile(corePath);
        console.logString(jsonContent);
        pauserContract = vm.parseJsonAddress(jsonContent, ".Pauser");
    }

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");
        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            if (configs[network].isHost) {
                continue;
            } else {
                // Create fork for this network
                forks[network] = vm.createSelectFork(network);

                vm.startBroadcast(key);
                Pauser(pauserContract).emergencyPauseMarket(MARKET_TO_PAUSE);
                vm.stopBroadcast();
            }

            console.log("-------------------- DONE");
        }
    }
}
