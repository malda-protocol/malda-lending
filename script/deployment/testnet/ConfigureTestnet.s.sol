// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Deployer} from "src/utils/Deployer.sol";

import {MarketRelease, Role, OracleFeed} from "../../deployers/Types.sol";

import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";

import {SetRole} from "../../configuration/SetRole.s.sol";
import {SetCollateralFactor} from "../../configuration/SetCollateralFactor.s.sol";
import {SupportMarket} from "../../configuration/SupportMarket.s.sol";
import {SetBorrowRateMaxMantissa} from "../../configuration/SetBorrowRateMaxMantissa.s.sol";
import {SetBorrowCap} from "../../configuration/SetBorrowCap.s.sol";
import {SetSupplyCap} from "../../configuration/SetSupplyCap.s.sol";
import {SetReserveFactor} from "../../configuration/SetReserveFactor.s.sol";
import {SetPriceFeedOnOracleV4} from "../../configuration/SetPriceFeedOnOracleV4.s.sol";
import {SetLiquidationBonus} from "../../configuration/SetLiquidationBonus.s.sol";

// forge script ConfigureTestnet --slow
// forge script ConfigureTestnet --slow  --multi --broadcast
contract ConfigureTestnet is DeployBaseRelease {
    using stdJson for string;

    address[] internal marketAddresses;
    uint256[] internal reserveFactors;
    uint256[] internal liquidationBonuses;
    address internal owner;
    Deployer internal deployer;
    address internal rolesContract;
    address internal zkVerifier;
    address internal operator;
    address internal oracle;
    address internal pauser;

    SetRole internal setRole;
    SupportMarket internal supportMarket;
    SetCollateralFactor internal setCollateralFactor;
    SetBorrowRateMaxMantissa internal setBorrowRateMaxMantissa;
    SetBorrowCap internal setBorrowCap;
    SetSupplyCap internal setSupplyCap;
    SetReserveFactor internal setReserveFactor;
    SetPriceFeedOnOracleV4 internal setFeed;
    SetLiquidationBonus internal setLiquidationBonus;

    error ADDRESSES_NOT_SET();
    error MARKET_ADDRESSES_NOT_SET();

    function setUp() public override {
        configPath = "deployment-config-testnet.json";
        super.setUp();

        feeds.push(
            OracleFeed({
                symbol: "mUSDCMock",
                defaultFeed: 0xdf0bD5072572A002ad0eeBAc58c4BCECA952A826,
                toSymbol: "USD",
                underlyingDecimals: 6
            })
        );
        feeds.push(
            OracleFeed({
                symbol: "USDC-M",
                defaultFeed: 0xdf0bD5072572A002ad0eeBAc58c4BCECA952A826,
                toSymbol: "USD",
                underlyingDecimals: 6
            })
        );
        feeds.push(
            OracleFeed({
                symbol: "mwstETHMock",
                defaultFeed: 0xa371FA57A42d9c72380e2959ceDbB21aE07AD210,
                toSymbol: "USD",
                underlyingDecimals: 18
            })
        );
        feeds.push(
            OracleFeed({
                symbol: "wstETH-M",
                defaultFeed: 0xa371FA57A42d9c72380e2959ceDbB21aE07AD210,
                toSymbol: "USD",
                underlyingDecimals: 18
            })
        );

        // SET before running it!
        deployer = Deployer(payable(0x6F6cA5F50B6b99a7298B4b7fE7E4Daa1f90552a2));
        rolesContract = 0xF7731a207D6F1423231Fe7fF80DaF4D9fa95a879;
        zkVerifier = 0xF2F6D7F7679eEB50284633B0851D7B1Af9E33ce9;
        operator = 0x3fbe703927ADDF1d950edC03D89D8886645532Af;
        oracle = 0xd9BD603C04371F2C8734e728E76AC88fAb2d45a0;
        pauser = 0x26D4830769b00774d033aAb92e4Ba07Ee8260a7e;

        // Available after `DeployMarketsTestnet`. MUST be in the same order as in "deployment-config-testnet.json"
        // There are only 2 markets so not a big overhead. The discussion is different for release scripts.
        marketAddresses.push(address(0x0A0873996508D0F4C5AD44A8Ce398A69A6bb8648));
        marketAddresses.push(address(0x8A2db4C15Ea83984f03567f5AeC89C46883f6D19));

        reserveFactors.push(uint256(100000000000000000));
        reserveFactors.push(uint256(50000000000000000));

        liquidationBonuses.push(uint256(1050000000000000000));
        liquidationBonuses.push(uint256(1060000000000000000));
        // SET before running it ^!

        // checks to make sure addresses were set
        if (
            oracle == address(0) || address(deployer) == address(0) || rolesContract == address(0)
                || zkVerifier == address(0) || operator == address(0) || pauser == address(0)
        ) {
            revert ADDRESSES_NOT_SET();
        }
        if (marketAddresses.length == 0 || marketAddresses[0] == address(0)) {
            revert MARKET_ADDRESSES_NOT_SET();
        }
    }

    function run() public {
        // Deploy to all networks
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Configuring %s ===", network);

            // Create fork for this network
            forks[network] = vm.createSelectFork(network);

            setRole = new SetRole();
            // Setup roles and chain connections
            _setRoles(network);

            owner = configs[network].deployer.owner;

            if (configs[network].isHost) {
                supportMarket = new SupportMarket();
                setCollateralFactor = new SetCollateralFactor();
                setBorrowRateMaxMantissa = new SetBorrowRateMaxMantissa();
                setBorrowCap = new SetBorrowCap();
                setSupplyCap = new SetSupplyCap();
                setReserveFactor = new SetReserveFactor();
                setFeed = new SetPriceFeedOnOracleV4();
                setLiquidationBonus = new SetLiquidationBonus();
                _configure(network);
            }

            console.log("-------------------- DONE");
        }
    }

    function _configure(string memory network) internal {
        uint256 feedsLength = feeds.length;
        for (uint256 i; i < feedsLength;) {
            setFeed.runTestnet(oracle, feeds[i].symbol, feeds[i].defaultFeed, feeds[i].underlyingDecimals);
            unchecked {
                ++i;
            }
        }

        uint256 marketsLength = configs[network].markets.length;
        for (uint256 i; i < marketsLength;) {
            _configureMarket(marketAddresses[i], liquidationBonuses[i], reserveFactors[i], configs[network].markets[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _configureMarket(
        address marketAddress,
        uint256 liquidationBonus,
        uint256 reserveFactor,
        MarketRelease memory market
    ) internal {
        // Configure market on host chain
        console.log("Configuring market", marketAddress);
        _configureMarket(
            marketAddress,
            liquidationBonus,
            reserveFactor,
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

        // Set supply cap
        _setSupplyCap(market, supplyCap);

        // Set liquidation incentives
        _setLiquidationIncentive(market, liquidationBonus);

        // Set reserve factor
        _setReserveFactor(market, reserveFactor);

        // Set borrow rate max mantissa
        _setBorrowRateMaxMantissa(market, borrowRateMaxMantissa);
    }

    function _supportMarket(address market) internal {
        supportMarket.run(operator, market);
    }

    function _setCollateralFactor(address market, uint256 collateralFactor) internal {
        setCollateralFactor.run(operator, market, collateralFactor);
    }

    function _setBorrowRateMaxMantissa(address market, uint256 borrowRateMaxMantissa) internal {
        setBorrowRateMaxMantissa.run(market, borrowRateMaxMantissa);
    }

    function _setBorrowCap(address market, uint256 borrowCap) internal {
        setBorrowCap.run(operator, market, borrowCap);
    }

    function _setSupplyCap(address market, uint256 supplyCap) internal {
        setSupplyCap.run(operator, market, supplyCap);
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

    function _setReserveFactor(address market, uint256 reserveFactor) internal {
        setReserveFactor.run(market, reserveFactor);
    }

    function _setLiquidationIncentive(address market, uint256 liquidationBonus) internal {
        setLiquidationBonus.run(operator, market, liquidationBonus);
    }
}
