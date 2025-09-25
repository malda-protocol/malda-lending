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
import {SetCollateralFactor} from "../../configuration/SetCollateralFactor.s.sol";
import {SetReserveFactor} from "../../configuration/SetReserveFactor.s.sol";
import {SetLiquidationBonus} from "../../configuration/SetLiquidationBonus.s.sol";
import {SetCloseFactor} from "../../configuration/SetCloseFactor.s.sol";
import {SupportMarket} from "../../configuration/SupportMarket.s.sol";
import {SetBorrowRateMaxMantissa} from "../../configuration/SetBorrowRateMaxMantissa.s.sol";
import {SetBorrowCap} from "../../configuration/SetBorrowCap.s.sol";
import {SetMinBorrowSize} from "../../configuration/SetMinBorrowSize.s.sol";
import {SetSupplyCap} from "../../configuration/SetSupplyCap.s.sol";
import {SetPriceFeedOnOracleV4} from "../../configuration/SetPriceFeedOnOracleV4.s.sol";
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
