// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {
    DeployConfig,
    MarketRelease,
    Role,
    InterestConfig,
    OracleConfigRelease,
    OracleFeed
} from "../../deployers/Types.sol";

import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";

contract InitialMint is DeployBaseRelease {
    using stdJson for string;

    address[] marketList;

    address constant RECEIVER = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();


        string memory marketsOutputPath = "script/deployment/mainnet/output/release-deployed-market-addresses.json";
        string memory rawMarketJson = vm.readFile(marketsOutputPath);
        uint256 length = 2;
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
    }

    function run() public {
        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            if (configs[network].isHost) {
                console.log("\n=== Initial mint on Linea %s ===", network);

                // Create fork for this network
                forks[network] = vm.createSelectFork(network);

                _configure();
            }

            console.log("-------------------- DONE");
        }
    }

    function _configure() internal {
        uint256 key = vm.envUint("PRIVATE_KEY");

        uint256 marketsLength = marketList.length;
        console.log("Configuring markets, count: ", marketsLength);
        for (uint256 i; i < marketsLength; ++i) {
            console.log("Market index: ", i);
            console.log("Market address: ", marketList[i]);

            mErc20Host m = mErc20Host(marketList[i]);

            // Approve underlying for mint
            address underlying = m.underlying();
            vm.startBroadcast(key);
            IERC20Metadata(underlying).approve(address(m), 10_000);
            vm.stopBroadcast();

            // Mint into RECEIVER
            vm.startBroadcast(key);
            m.mint(10_000, RECEIVER, 0);
            vm.stopBroadcast();

            // Transfer minted market tokens to burn address
            uint256 bal = m.balanceOf(RECEIVER);
            vm.startBroadcast(key);
            IERC20Metadata(address(m)).transfer(address(0), bal);
            vm.stopBroadcast();

            // Verify balances of address(0)
            uint256 addr0Balance = m.balanceOf(address(0));
            console.log("Burn address balance: ", addr0Balance);

        }
    }
}
