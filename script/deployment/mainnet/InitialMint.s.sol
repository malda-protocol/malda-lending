// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

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

            vm.startBroadcast(key);
            // Approve underlying for mint
            IERC20(m.underlying()).approve(address(m), 10_000);
            // Mint into RECEIVER
            m.mint(10_000, RECEIVER, 0);

            // @audit-question possibly introduce try-catch to handle transfer failure
            // Transfer minted market tokens to burn address (@audit-question why not just call burn?)
            bool success = IERC20(address(m)).transfer(address(0), m.balanceOf(RECEIVER));
            require(success, "Transfer failed");
            vm.stopBroadcast();

            // Verify balances of address(0)
            uint256 addr0Balance = m.balanceOf(address(0));
            console.log("Burn address balance: ", addr0Balance);
        }
    }
}
