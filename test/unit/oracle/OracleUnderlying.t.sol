// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Roles} from "src/Roles.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Operator} from "src/Operator/Operator.sol";

contract MockChainlinkOracle {
    uint256 public decimals;
    uint256 public price;

    constructor(uint256 _price, uint256 _decimals) {
        price = _price;
        decimals = _decimals;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 1;
        answer = int256(price);
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }
}

contract DummyToken {
    string public symbol;
    uint256 public decimals;

    constructor(string memory _symbol, uint256 _decimals) {
        symbol = _symbol;
        decimals = _decimals;
    }
}

contract DummyMToken {
    address public underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }
}

contract MixedPriceOracleV3_Test is Operator, Test {
    MixedPriceOracleV3 internal mixedPriceOracle;

    DummyToken internal BTC;
    DummyMToken internal mBTC;
    uint256 internal usdPerBitcoin = 70_000;
    uint256 internal bitcoinDecimals = 8;

    DummyToken internal ETH;
    DummyMToken internal mETH;
    uint256 internal usdPerEth = 2_500;
    uint256 internal ethDecimals = 18;

    DummyToken internal USDC;
    DummyMToken internal mUSDC;
    uint256 internal usdPerUsdc = 1;
    uint256 internal usdcDecimals = 6;

    DummyToken internal LargeDecimalsToken;
    DummyMToken internal mLargeDecimalsToken;
    uint256 internal usdPerLargeToken = 1;
    uint256 internal largeTokenDecimals = 30;

    uint256 internal feedDecimals = 8; //chainlink returns answers in 8 decimals

    function newUSDOracle(uint256 usdPerToken) public returns (MockChainlinkOracle) {
        uint256 decimals = feedDecimals;
        uint256 price = 10 ** decimals * usdPerToken;
        return new MockChainlinkOracle(price, decimals);
    }

    function newOracleInBase(uint256 usdPerQuotedToken, uint256 usdPerBaseToken) public returns (MockChainlinkOracle) {
        uint256 decimals = feedDecimals;
        uint256 price = 10 ** decimals * usdPerQuotedToken / usdPerBaseToken;
        return new MockChainlinkOracle(price, decimals);
    }

    function setUp() public {
        BTC = new DummyToken("BTC", bitcoinDecimals);
        ETH = new DummyToken("ETH", ethDecimals);
        USDC = new DummyToken("USDC", usdcDecimals);
        LargeDecimalsToken = new DummyToken("Large", largeTokenDecimals);

        mBTC = new DummyMToken(address(BTC));
        mETH = new DummyMToken(address(ETH));
        mUSDC = new DummyMToken(address(USDC));
        mLargeDecimalsToken = new DummyMToken(address(LargeDecimalsToken));

        MockChainlinkOracle usdPerUSDCOracle = newUSDOracle(usdPerUsdc);
        MockChainlinkOracle usdcPerEthOracle = newOracleInBase(usdPerEth, usdPerUsdc);
        MockChainlinkOracle ethPerBTCOracle = newOracleInBase(usdPerBitcoin, usdPerEth);

        uint256 numOracles = 3;
        string[] memory symbols = new string[](numOracles);
        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](numOracles);

        symbols[0] = "USDC";
        configs[0] = IDefaultAdapter.PriceConfig({
            defaultFeed: address(usdPerUSDCOracle), toSymbol: "USD", underlyingDecimals: usdcDecimals
        });

        symbols[1] = "ETH";
        configs[1] = IDefaultAdapter.PriceConfig({
            defaultFeed: address(usdcPerEthOracle), toSymbol: "USDC", underlyingDecimals: ethDecimals
        });

        symbols[2] = "BTC";
        configs[2] = IDefaultAdapter.PriceConfig({
            defaultFeed: address(ethPerBTCOracle), toSymbol: "ETH", underlyingDecimals: bitcoinDecimals
        });

        address roles = address(new Roles(address(this)));
        uint256 stalenessPeriod = 100;

        mixedPriceOracle = new MixedPriceOracleV3(symbols, configs, roles, stalenessPeriod);
        // Set the oracleOperator to our mocked oracle
        oracleOperator = address(mixedPriceOracle);
    }

    function test_getPriceUSD() public view {
        uint256 btcPrice = mixedPriceOracle.getUnderlyingPrice(address(mBTC));
        uint256 ethPrice = mixedPriceOracle.getUnderlyingPrice(address(mETH));
        uint256 usdcPrice = mixedPriceOracle.getUnderlyingPrice(address(mUSDC));

        console.log("btcPrice", btcPrice);
        console.log("ethPrice", ethPrice);
        console.log("usdcPrice", usdcPrice);
        assertEq(btcPrice, 10 ** (36 - bitcoinDecimals) * usdPerBitcoin);
        assertEq(ethPrice, 10 ** (36 - ethDecimals) * usdPerEth);
        assertEq(usdcPrice, 10 ** (36 - usdcDecimals) * usdPerUsdc);

        assertEq(usdPerBitcoin * 1e8, _convertMarketAmountToUSDValue(1e8, address(mBTC)), "A");
        assertEq(usdPerEth * 1e8, _convertMarketAmountToUSDValue(1e18, address(mETH)), "B");
        assertEq(usdPerUsdc * 1e8, _convertMarketAmountToUSDValue(1e6, address(mUSDC)), "C");
    }
}
