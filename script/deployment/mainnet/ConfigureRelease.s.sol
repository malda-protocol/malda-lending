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

contract ConfigureRelease is DeployBaseRelease {
    using stdJson for string;

    address[] marketList;

    mapping(string => uint256) public collateralFactors;
    mapping(string => uint256) public reserveFactors;
    mapping(string => uint256) public liquidationBonuses;
    mapping(string => uint256) public borrowCaps;
    mapping(string => uint256) public minBorrowSize;
    mapping(string => MarketRelease) public fullConfigs;

    address oracle;
    address operator;
    address rolesContract;
    SetRole setRole;
    SupportMarket supportMarket;
    SetCollateralFactor setCollateralFactor;
    SetReserveFactor setReserveFactor;
    SetLiquidationBonus setLiquidationBonus;
    SetBorrowRateMaxMantissa setBorrowRateMaxMantissa;
    SetBorrowCap setBorrowCap;
    SetMinBorrowSize setMinBorrowSize;
    SetSupplyCap setSupplyCap;
    SetPriceFeedOnOracleV4 setFeed;
    SetCloseFactor setCloseFactor;
    SetWhitelistEnabled setWhitelistEnabled;
    SetWhitelistedUsersOnGateway setWhitelistEnabledOnExtension;

    uint256 constant DEFAULT_CLOSE_FACTOR = 0.5e18; //50%

    function setUp() public override {
        configPath = "deployment-config-release.json";
        super.setUp();

        // borrow caps
        borrowCaps["mUSDC"]  = 0;
        borrowCaps["mUSDT"]  = 0;
        borrowCaps["mWETH"]  = 0;
        borrowCaps["mwstETH"] = 0;
        borrowCaps["mWBTC"]  = 0;
        borrowCaps["mezETH"] = 0;
        borrowCaps["mweETH"] = 0;
        borrowCaps["mwrsETH"] = 0;

        // min caps
        minBorrowSize["mUSDC"]  = 10e6;       // 10 USDC (6 decimals)
        minBorrowSize["mUSDT"]  = 10e6;       // 10 USDT (6 decimals)
        minBorrowSize["mWETH"]  = 0.0025e18;  // 0.0025 ETH
        minBorrowSize["mwstETH"] = 0.0025e18; // 0.0025 wstETH
        minBorrowSize["mWBTC"]  = 0.0001e8;   // 0.0001 BTC (8 decimals)
        minBorrowSize["mezETH"] = 0.002e18;
        minBorrowSize["mweETH"] = 0.002e18;
        minBorrowSize["mwrsETH"] = 0.002e18;

        // collateral factors
        collateralFactors["mUSDC"]  = 900000000000000000; // 0.90
        collateralFactors["mUSDT"]  = 900000000000000000; // 0.90
        collateralFactors["mWETH"]  = 830000000000000000; // 0.83
        collateralFactors["mwstETH"] = 810000000000000000; // 0.81
        collateralFactors["mWBTC"]  = 780000000000000000; // 0.78
        collateralFactors["mezETH"] = 750000000000000000; // 0.75
        collateralFactors["mweETH"] = 800000000000000000;
        collateralFactors["mwrsETH"] = 750000000000000000;

        // reserve factors
        reserveFactors["mUSDC"]  = 100000000000000000; // 0.10
        reserveFactors["mUSDT"]  = 100000000000000000; // 0.10
        reserveFactors["mWETH"]  = 150000000000000000; // 0.15
        reserveFactors["mwstETH"] = 50000000000000000; // 0.05
        reserveFactors["mWBTC"]  = 500000000000000000; // 0.50
        reserveFactors["mezETH"] = 450000000000000000; // 0.45
        reserveFactors["mweETH"] = 450000000000000000;
        reserveFactors["mwrsETH"] = 450000000000000000;

        // liquidation bonuses
        liquidationBonuses["mUSDC"]  = 1050000000000000000; // 1.05
        liquidationBonuses["mUSDT"]  = 1050000000000000000; // 1.05
        liquidationBonuses["mWETH"]  = 1050000000000000000; // 1.05
        liquidationBonuses["mwstETH"] = 1060000000000000000; // 1.06
        liquidationBonuses["mWBTC"]  = 1050000000000000000; // 1.05
        liquidationBonuses["mezETH"] = 1070000000000000000; // 1.07
        liquidationBonuses["mweETH"] = 1070000000000000000;
        liquidationBonuses["mwrsETH"] = 1070000000000000000;

        // full configs
        fullConfigs["mUSDC"] = MarketRelease({
            borrowCap: borrowCaps["mUSDC"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mUSDC"],
            decimals: 0,
            interestModel: InterestConfig({
                baseRate: 0,
                blocksPerYear: 0,
                jumpMultiplier: 0,
                kink: 0,
                multiplier: 0,
                name: "mUSDC Interest Model"
            }),
            name: "mUSDC",
            supplyCap: 0,
            symbol: "mUSDC",
            underlying: address(0),
            reserveFactor: reserveFactors["mUSDC"],
            liquidationBonus: liquidationBonuses["mUSDC"]
        });

        fullConfigs["mWETH"] = MarketRelease({
            borrowCap: borrowCaps["mWETH"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mWETH"],
            decimals: 0,
            interestModel: InterestConfig({
                baseRate: 0,
                blocksPerYear: 0,
                jumpMultiplier: 0,
                kink: 0,
                multiplier: 0,
                name: "mWETH Interest Model"
            }),
            name: "mWETH",
            supplyCap: 0,
            symbol: "mWETH",
            underlying: address(0),
            reserveFactor: reserveFactors["mWETH"],
            liquidationBonus: liquidationBonuses["mWETH"]
        });

        fullConfigs["mUSDT"] = MarketRelease({
            borrowCap: borrowCaps["mUSDT"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mUSDT"],
            decimals: 0,
            interestModel: InterestConfig({
                baseRate: 0,
                blocksPerYear: 0,
                jumpMultiplier: 0,
                kink: 0,
                multiplier: 0,
                name: "mUSDT Interest Model"
            }),
            name: "mUSDT",
            supplyCap: 0,
            symbol: "mUSDT",
            underlying: address(0),
            reserveFactor: reserveFactors["mUSDT"],
            liquidationBonus: liquidationBonuses["mUSDT"]
        });

        fullConfigs["mWBTC"] = MarketRelease({
            borrowCap: borrowCaps["mWBTC"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mWBTC"],
            decimals: 0,
            interestModel: InterestConfig({
                baseRate: 0,
                blocksPerYear: 0,
                jumpMultiplier: 0,
                kink: 0,
                multiplier: 0,
                name: "mWBTC Interest Model"
            }),
            name: "mWBTC",
            supplyCap: 0,
            symbol: "mWBTC",
            underlying: address(0),
            reserveFactor: reserveFactors["mWBTC"],
            liquidationBonus: liquidationBonuses["mWBTC"]
        });

        fullConfigs["mwstETH"] = MarketRelease({
            borrowCap: borrowCaps["mwstETH"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mwstETH"],
            decimals: 0,
            interestModel: InterestConfig({
                baseRate: 0,
                blocksPerYear: 0,
                jumpMultiplier: 0,
                kink: 0,
                multiplier: 0,
                name: "mwstETH Interest Model"
            }),
            name: "mwstETH",
            supplyCap: 0,
            symbol: "mwstETH",
            underlying: address(0),
            reserveFactor: reserveFactors["mwstETH"],
            liquidationBonus: liquidationBonuses["mwstETH"]
        });

        fullConfigs["mezETH"] = MarketRelease({
            borrowCap: borrowCaps["mezETH"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mezETH"],
            decimals: 0,
            interestModel: InterestConfig({
                baseRate: 0,
                blocksPerYear: 0,
                jumpMultiplier: 0,
                kink: 0,
                multiplier: 0,
                name: "mezETH Interest Model"
            }),
            name: "mezETH",
            supplyCap: 0,
            symbol: "mezETH",
            underlying: address(0),
            reserveFactor: reserveFactors["mezETH"],
            liquidationBonus: liquidationBonuses["mezETH"]
        });
                fullConfigs["mweETH"] = MarketRelease({
            borrowCap: borrowCaps["mweETH"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mweETH"],
            decimals: 18,
            interestModel: InterestConfig({
                baseRate: 317091247,
                blocksPerYear: 31536000,
                jumpMultiplier: 3000002316638736000,
                kink: 400000000000000000,
                multiplier: 27999732233587200,
                name: "mweETH Interest Model"
            }),
            name: "mweETH",
            supplyCap: 0,
            symbol: "mweETH",
            underlying: 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6,
            reserveFactor: reserveFactors["mweETH"],
            liquidationBonus: liquidationBonuses["mweETH"]
        });

        fullConfigs["mwrsETH"] = MarketRelease({
            borrowCap: borrowCaps["mwrsETH"],
            borrowRateMaxMantissa: 0.0005e16,
            collateralFactor: collateralFactors["mwrsETH"],
            decimals: 18,
            interestModel: InterestConfig({
                baseRate: 0,
                blocksPerYear: 31536000,
                jumpMultiplier: 3000002316638736000,
                kink: 400000000000000000,
                multiplier: 27999732233587200,
                name: "mwrsETH Interest Model"
            }),
            name: "mwrsETH",
            supplyCap: 0,
            symbol: "mwrsETH",
            underlying: 0xD2671165570f41BBB3B0097893300b6EB6101E6C,
            reserveFactor: reserveFactors["mwrsETH"],
            liquidationBonus: liquidationBonuses["mwrsETH"]
        });

        string memory marketsOutputPath = "script/deployment/mainnet/output/release-deployed-market-addresses.json";
        string memory rawMarketJson = vm.readFile(marketsOutputPath);
        uint256 length = 6;
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
        oracle = vm.parseJsonAddress(jsonContent, ".Oracle");
        operator = vm.parseJsonAddress(jsonContent, ".Operator");
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
            _setRoles(network);

            if (configs[network].isHost) {
                console.log("Configuring LINEA");
                supportMarket = new SupportMarket();
                setCollateralFactor = new SetCollateralFactor();
                setBorrowRateMaxMantissa = new SetBorrowRateMaxMantissa();
                setBorrowCap = new SetBorrowCap();
                setCloseFactor = new SetCloseFactor();
                setMinBorrowSize = new SetMinBorrowSize();
                setSupplyCap = new SetSupplyCap();
                setReserveFactor = new SetReserveFactor();
                setFeed = new SetPriceFeedOnOracleV4();
                setLiquidationBonus = new SetLiquidationBonus();
                setWhitelistEnabled = new SetWhitelistEnabled();
                _configure(network);
            } else {
                console.log("Configuring EXTENSION");
                setWhitelistEnabledOnExtension = new SetWhitelistedUsersOnGateway();
                setWhitelistEnabledOnExtension.run(marketList);
            }

            console.log("-------------------- DONE");
        }
    }

    function _configure(string memory network) internal {
        console.log("Configuring whitelist", address(operator));
        setWhitelistEnabled.run(operator);

        console.log("Configuring close factor on operator", address(operator));
        setCloseFactor.run(operator, DEFAULT_CLOSE_FACTOR);
        
        console.log("Settings feeds on oracle", address(oracle));
        setFeed.run(oracle);

        uint256 marketsLength = marketList.length;
        console.log("Configuring markets, count: ", marketsLength);
        for (uint256 i; i < marketsLength; ++i) {
            console.log("Market name: ");
            console.logString(configs[network].markets[i].name);
            MarketRelease storage mktRelease = fullConfigs[configs[network].markets[i].name];
            _configureMarket(marketList[i], mktRelease);
        }
    }

    function _configureMarket(address marketAddress, MarketRelease storage market) internal {
        // Configure market on host chain
        console.log("Configuring market", marketAddress);
        _configureMarket(
            marketAddress,
            market.liquidationBonus,
            market.reserveFactor,
            market.collateralFactor,
            market.borrowCap,
            market.supplyCap,
            market.borrowRateMaxMantissa
        );
        console.log("Market configured");
    }

    function _configureMarket(
        address market,
        uint256 liquidationBonus,
        uint256 reserveFactor,
        uint256 collateralFactor,
        uint256 borrowCap,
        uint256 supplyCap,
        uint256 borrowRateMaxMantissa
    ) internal {
        // Support market
        _supportMarket(market);

        // Set collateral factor
        _setCollateralFactor(market, collateralFactor);

        // Set borrow cap
        _setBorrowCap(market, borrowCap);

        // Set min borrow size
        _setMinBorrowSize(market, minBorrowSize[IERC20Metadata(market).symbol()]);

        // Set supply cap
        _setSupplyCap(market, supplyCap);

        // Set liquidation incentives
        _setLiquidationIncentive(market, liquidationBonus);

        // Set reserve factor
        _setReserveFactor(market, reserveFactor);

        // Set borrow rate max mantissa
        _setBorrowRateMaxMantissa(market, borrowRateMaxMantissa);
    }

    function _setRoles(string memory network) internal {
        uint256 rolesLength = configs[network].roles.length;
        for (uint256 i = 0; i < rolesLength; i++) {
            Role memory role = configs[network].roles[i];
            for (uint256 j = 0; j < role.accounts.length; j++) {
                setRole.run(rolesContract, role.accounts[j], keccak256(abi.encodePacked(role.roleName)), true);
            }
        }
    }

    function _supportMarket(address market) internal {
        supportMarket.run(operator, market);
    }

    function _setCollateralFactor(address market, uint256 collateralFactor) internal {
        setCollateralFactor.run(operator, market, collateralFactor);
    }

    function _setReserveFactor(address market, uint256 reserveFactor) internal {
        setReserveFactor.run(market, reserveFactor);
    }

    function _setLiquidationIncentive(address market, uint256 liquidationBonus) internal {
        setLiquidationBonus.run(operator, market, liquidationBonus);
    }

    function _setBorrowRateMaxMantissa(address market, uint256 borrowRateMaxMantissa) internal {
        setBorrowRateMaxMantissa.run(market, borrowRateMaxMantissa);
    }

    function _setBorrowCap(address market, uint256 borrowCap) internal {
        setBorrowCap.run(operator, market, borrowCap);
    }
    
    function _setMinBorrowSize(address market, uint256 amount) internal {
        setMinBorrowSize.run(operator, market, amount);
    }

    function _setSupplyCap(address market, uint256 supplyCap) internal {
        setSupplyCap.run(operator, market, supplyCap);
    }
}
