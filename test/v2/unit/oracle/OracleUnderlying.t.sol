// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
import {Operator} from "src/Operator/Operator.sol";
import {Roles} from "src/Roles.sol";

import {DummyMToken, DummyToken, MockChainlinkOracle} from "test/v2/mocks/oracles/OracleUnderlyingMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract OracleUnderlyingTest is Operator, BaseTest {
    uint256 internal constant FEED_DECIMALS = 8;

    uint256 internal constant USD_PER_BITCOIN = 70_000;
    uint256 internal constant USD_PER_ETH = 2_500;
    uint256 internal constant USD_PER_USDC = 1;

    uint256 internal constant BITCOIN_DECIMALS = 8;
    uint256 internal constant ETH_DECIMALS = 18;
    uint256 internal constant USDC_DECIMALS = 6;

    MixedPriceOracleV3 internal mixedPriceOracle;
    Roles internal roles;

    DummyToken internal btc;
    DummyMToken internal mBtc;

    DummyToken internal eth;
    DummyMToken internal mEth;

    DummyToken internal usdc;
    DummyMToken internal mUsdc;

    function setUp() public override {
        super.setUp();

        roles = new Roles(users.admin);

        btc = new DummyToken("BTC", BITCOIN_DECIMALS);
        eth = new DummyToken("ETH", ETH_DECIMALS);
        usdc = new DummyToken("USDC", USDC_DECIMALS);

        mBtc = new DummyMToken(address(btc));
        mEth = new DummyMToken(address(eth));
        mUsdc = new DummyMToken(address(usdc));

        MockChainlinkOracle usdPerUsdcOracle = _newUsdOracle(USD_PER_USDC);
        MockChainlinkOracle usdcPerEthOracle = _newOracleInBase(USD_PER_ETH, USD_PER_USDC);
        MockChainlinkOracle ethPerBtcOracle = _newOracleInBase(USD_PER_BITCOIN, USD_PER_ETH);

        string[] memory symbols = new string[](3);
        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](3);

        symbols[0] = "USDC";
        configs[0] = IDefaultAdapter.PriceConfig({
            defaultFeed: address(usdPerUsdcOracle), toSymbol: "USD", underlyingDecimals: USDC_DECIMALS
        });

        symbols[1] = "ETH";
        configs[1] = IDefaultAdapter.PriceConfig({
            defaultFeed: address(usdcPerEthOracle), toSymbol: "USDC", underlyingDecimals: ETH_DECIMALS
        });

        symbols[2] = "BTC";
        configs[2] = IDefaultAdapter.PriceConfig({
            defaultFeed: address(ethPerBtcOracle), toSymbol: "ETH", underlyingDecimals: BITCOIN_DECIMALS
        });

        mixedPriceOracle = new MixedPriceOracleV3(symbols, configs, address(roles), 100);
        oracleOperator = address(mixedPriceOracle);
    }

    ////////////////////////////////////////////////////////////
    //                   getUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_unit_getUnderlyingPrice_success() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 btcPrice = mixedPriceOracle.getUnderlyingPrice(address(mBtc));
        uint256 ethPrice = mixedPriceOracle.getUnderlyingPrice(address(mEth));
        uint256 usdcPrice = mixedPriceOracle.getUnderlyingPrice(address(mUsdc));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(btcPrice, 10 ** (36 - BITCOIN_DECIMALS) * USD_PER_BITCOIN, "assertEq failed: values do not match");
        assertEq(ethPrice, 10 ** (36 - ETH_DECIMALS) * USD_PER_ETH, "assertEq failed: values do not match");
        assertEq(usdcPrice, 10 ** (36 - USDC_DECIMALS) * USD_PER_USDC, "assertEq failed: values do not match");
    }

    function test_fuzz_convertMarketAmountToUSDValue_success(uint256 rawAmount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxPrice = 10 ** (36 - BITCOIN_DECIMALS) * USD_PER_BITCOIN;
        uint256 maxAmount = type(uint256).max / maxPrice;
        uint256 amount = bound(rawAmount, 1, maxAmount);

        uint256 btcValue = _convertMarketAmountToUSDValue(amount, address(mBtc));
        uint256 ethValue = _convertMarketAmountToUSDValue(amount, address(mEth));
        uint256 usdcValue = _convertMarketAmountToUSDValue(amount, address(mUsdc));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            btcValue,
            _expectedUsdValue(amount, USD_PER_BITCOIN, BITCOIN_DECIMALS),
            "assertEq failed: values do not match"
        );
        assertEq(ethValue, _expectedUsdValue(amount, USD_PER_ETH, ETH_DECIMALS), "assertEq failed: values do not match");
        assertEq(
            usdcValue, _expectedUsdValue(amount, USD_PER_USDC, USDC_DECIMALS), "assertEq failed: values do not match"
        );
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _newUsdOracle(uint256 usdPerToken) internal returns (MockChainlinkOracle) {
        uint256 price = 10 ** FEED_DECIMALS * usdPerToken;
        return new MockChainlinkOracle(price, FEED_DECIMALS);
    }

    function _newOracleInBase(uint256 usdPerQuotedToken, uint256 usdPerBaseToken)
        internal
        returns (MockChainlinkOracle)
    {
        uint256 price = (10 ** FEED_DECIMALS) * usdPerQuotedToken / usdPerBaseToken;
        return new MockChainlinkOracle(price, FEED_DECIMALS);
    }

    function _expectedUsdValue(uint256 amount, uint256 usdPerToken, uint256 decimals) internal pure returns (uint256) {
        if (decimals <= 8) {
            return amount * usdPerToken * (10 ** (8 - decimals));
        }

        return (amount * usdPerToken) / (10 ** (decimals - 8));
    }
}
