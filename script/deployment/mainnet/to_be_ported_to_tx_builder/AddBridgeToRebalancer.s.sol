// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";

import {DeployBaseRelease} from "../../../deployers/DeployBaseRelease.sol";

interface IAcrossBridge {
    function setWhitelistedRelayer(uint32 _dstId, address _relayer, bool status) external;
}

contract AddBridgeToRebalancer is DeployBaseRelease {
    using stdJson for string;

    address public rebalancerContract;
    address public bridgeContract;

    address[] public marketList;

    uint32[] public whitelistChains;
    mapping(uint32 chainId => address[] tokenList) public tokens;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        bridgeContract = 0x0D6C5079CdCdC7d84104F0598EBFAd943dc5281e;

        // Linea (chainId: 59144)
        tokens[59144] = [
            0x176211869cA2b568f2A7D4EE941E073a821EE1ff, // mUSDC
            0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f, // mWETH
            0xA219439258ca9da29E9Cc4cE5596924745e12B93, // mUSDT
            0x3aAB2285ddcDdaD8edf438C1bAB47e1a9D05a9b4 // mWBTC
        ];

        // Base (chainId: 8453)
        tokens[8453] = [
            0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // mUSDC
            0x4200000000000000000000000000000000000006, // mWETH
            0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2, // mUSDT
            0x0555E30da8f98308EdB960aa94C0Db47230d2B9c // mWBTC
        ];

        // Mainnet (chainId: 1)
        tokens[1] = [
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // mUSDC
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // mWETH
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // mUSDT
            0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 // mWBTC
        ];

        marketList.push(0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b);
        marketList.push(0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99);
        marketList.push(0x66DfCBf23319D68bdF0cB57797Fcc0A64d2265f8);
        marketList.push(0x0E5ad58f827f53C9F92c71319b77772F2a1FBdb2);

        console.log("Registered no of markets:", marketList.length);
        for (uint256 i; i < marketList.length; ++i) {
            console.log(" - market: ", marketList[i]);
        }

        string memory corePath = "script/deployment/mainnet/output/release-deployed-core-addresses.json";
        string memory jsonContent = vm.readFile(corePath);
        console.logString(jsonContent);
        rebalancerContract = vm.parseJsonAddress(jsonContent, ".Rebalancer");
    }

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");

        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Configuring %s ===", network);

            uint32 crtChainId = configs[network].chainId;

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            console.log("Setting whitelisted bridges");
            vm.startBroadcast(key);
            Rebalancer(rebalancerContract)
                .setWhitelistedBridgeStatus(address(0xa952cEB0617231C94F88CF52c8E512E224B3972D), false);
            Rebalancer(rebalancerContract).setWhitelistedBridgeStatus(address(bridgeContract), true);
            vm.stopBroadcast();

            console.log("Setting allowed tokens per bridge");
            address[] memory tknsArr = tokens[crtChainId];
            vm.startBroadcast(key);
            Rebalancer(rebalancerContract).setAllowedTokens(address(bridgeContract), tknsArr, true);
            Rebalancer(rebalancerContract)
                .setAllowedTokens(address(0xa952cEB0617231C94F88CF52c8E512E224B3972D), tknsArr, false);
            vm.stopBroadcast();

            console.log("Setting whitelisted relayer for across bridge");
            vm.startBroadcast(key);
            IAcrossBridge(bridgeContract).setWhitelistedRelayer(1, address(0), true);
            IAcrossBridge(bridgeContract).setWhitelistedRelayer(8453, address(0), true);
            IAcrossBridge(bridgeContract).setWhitelistedRelayer(59144, address(0), true);
            vm.stopBroadcast();

            console.log("-------------------- DONE");
        }
    }
}
