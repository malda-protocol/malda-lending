// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";

import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";
import {SetRole} from "../../configuration/SetRole.s.sol";

contract ConfigureRebalancer is DeployBaseRelease {
    using stdJson for string;

    address internal rolesContract;
    address internal rebalancerContract;
    address internal acrossContract;
    address internal everclearContract;

    SetRole internal setRole;
    address[] internal marketList;

    uint32[] internal whitelistChains;
    mapping(uint32 chainId => address[] tokenList) internal allowedAcrossTokens;
    mapping(uint32 chainId => address[] tokenList) internal allowedEverclearTokens;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        whitelistChains.push(1);
        whitelistChains.push(8453);
        whitelistChains.push(59144);

        // Linea (chainId: 59144)
        allowedAcrossTokens[59144] = [
            0x176211869cA2b568f2A7D4EE941E073a821EE1ff, // mUSDC
            0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f, // mWETH
            0xA219439258ca9da29E9Cc4cE5596924745e12B93, // mUSDT
            0x3aAB2285ddcDdaD8edf438C1bAB47e1a9D05a9b4, // mWBTC
            0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F, // mwstETH
            0x2416092f143378750bb29b79eD961ab195CcEea5 // mezETH
        ];

        // Base (chainId: 8453)
        allowedAcrossTokens[8453] = [
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // mUSDC
            0x4200000000000000000000000000000000000006, // mWETH
            0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2, // mUSDT
            0x0555E30da8f98308EdB960aa94C0Db47230d2B9c, // mWBTC
            0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452 // mwstETH
        ];

        // Mainnet (chainId: 1)
        allowedAcrossTokens[1] = [
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // mUSDC
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // mWETH
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // mUSDT
            0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // mWBTC
            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 // mwstETH
        ];

        // Linea (chainId: 59144)
        allowedEverclearTokens[59144] = [
            0x176211869cA2b568f2A7D4EE941E073a821EE1ff, // mUSDC
            0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f, // mWETH
            0xA219439258ca9da29E9Cc4cE5596924745e12B93, // mUSDT
            0x3aAB2285ddcDdaD8edf438C1bAB47e1a9D05a9b4, // mWBTC
            0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F, // mwstETH
            0x2416092f143378750bb29b79eD961ab195CcEea5 // mezETH
        ];

        // Base (chainId: 8453)
        allowedEverclearTokens[8453] = [
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // mUSDC
            0x4200000000000000000000000000000000000006, // mWETH
            0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2, // mUSDT
            0x0555E30da8f98308EdB960aa94C0Db47230d2B9c, // mWBTC
            0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452 // mwstETH
        ];

        // Mainnet (chainId: 1)
        allowedEverclearTokens[1] = [
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // mUSDC
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // mWETH
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // mUSDT
            0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // mWBTC
            0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 // mwstETH
        ];

        string memory marketsOutputPath = "script/deployment/mainnet/output/release-deployed-market-addresses.json";
        string memory rawMarketJson = vm.readFile(marketsOutputPath);
        uint256 length = 6;
        marketList = new address[](length);
        console.log("Markets: ");
        for (uint256 i; i < length; ++i) {
            string memory base = string.concat("[", vm.toString(i), "]");

            address marketAddr = vm.parseJsonAddress(rawMarketJson, string.concat(base, ".address"));
            //ezETH only available on Linea
            if (marketAddr != address(0) && marketAddr != 0x867B44af79da71684508c25a1323db3cce5bC23D) {
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

            // set whitelisted destinations
            console.log("Setting whitelisted destinations");
            uint32 crtChainId = configs[network].chainId;
            for (uint256 j; j < whitelistChains.length; ++j) {
                if (whitelistChains[j] != crtChainId) {
                    console.log(" - for chain: ", whitelistChains[j]);
                    vm.startBroadcast(key);
                    Rebalancer(rebalancerContract).setWhitelistedDestination(whitelistChains[j], true);
                    vm.stopBroadcast();
                }
            }

            console.log("Setting whitelisted bridges");
            vm.startBroadcast(key);
            Rebalancer(rebalancerContract).setWhitelistedBridgeStatus(address(acrossContract), true);
            Rebalancer(rebalancerContract).setWhitelistedBridgeStatus(address(everclearContract), true);
            vm.stopBroadcast();

            console.log("Setting allowed tokens per bridge");
            address[] memory accrossTokensArr = allowedAcrossTokens[crtChainId];
            address[] memory everclearTokensArr = allowedEverclearTokens[crtChainId];
            vm.startBroadcast(key);
            Rebalancer(rebalancerContract).setAllowedTokens(address(acrossContract), accrossTokensArr, true);
            Rebalancer(rebalancerContract).setAllowedTokens(address(everclearContract), everclearTokensArr, true);
            vm.stopBroadcast();

            console.log("Setting allowed markets");
            vm.startBroadcast(key);
            Rebalancer(rebalancerContract).setAllowList(marketList, true);
            Rebalancer(rebalancerContract).setMarketStatus(marketList, true);
            vm.stopBroadcast();

            console.log("-------------------- DONE");
        }
    }
}
