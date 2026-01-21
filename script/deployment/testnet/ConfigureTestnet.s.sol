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
        deployer = Deployer(payable(0x8a7AcF4af576ba88708145F516d043148c7f9AB0));
        rolesContract = 0xfe32FC2Ca64563c489cb7A591b51B0986D2A4E46;
        zkVerifier = 0xc05C044374Ae473ebe281be8e17e175d92798261;
        operator = 0x0F3bB5cA4B83b04D5ff1f4662b3E601fC9cc6baA;
        oracle = 0x4855A23fA9a09C9DDfC11c29d810A209B163Ca6c;
        pauser = 0x7F091d235a414e75D038564a1534FB7c0E629600;

        // Available after `DeployMarketsTestnet`. MUST be in the same order as in "deployment-config-testnet.json"
        // There are only 2 markets so not a big overhead. The discussion is different for release scripts.
        marketAddresses.push(address(0x327403c5E1598EE71E2e1a96691d4047fdAC323a));
        marketAddresses.push(address(0xdE4F93C7cFCE30c941A06b19Ea1DE440B69E6329));

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
