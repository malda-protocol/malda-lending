// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";

import {MockAdapter, MockRoles, MockToken} from "test/v2/mocks/oracles/OracleV4Mocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract MixedPriceOracleV4Test is BaseTest {
    string internal constant SYMBOL = "MOCK";

    MixedPriceOracleV4 internal oracle;
    MockAdapter internal api3;
    MockAdapter internal chainlink;
    MockRoles internal roles;
    MockToken internal token;

    function setUp() public override {
        super.setUp();

        api3 = new MockAdapter();
        chainlink = new MockAdapter();
        roles = new MockRoles();
        token = new MockToken();

        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = _config(address(api3), address(chainlink), "USD", "USD", 18);

        oracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
        roles.allow(address(this));

        vm.warp(100 days);
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_constructor_revertsWith_MixedPriceOracle_AddressNotValid(
        uint8 underlyingDecimals,
        uint256 staleness
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        staleness = bound(staleness, 1, 30 days);

        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = _config(address(api3), address(chainlink), "USD", "USD", underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_AddressNotValid.selector);

        new MixedPriceOracleV4(symbols, configs, address(0), staleness);
    }

    ////////////////////////////////////////////////////////////
    //                      setStaleness                      //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setStaleness_success(uint256 newStaleness) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newStaleness = bound(newStaleness, 1, 30 days);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.StalenessUpdated(SYMBOL, newStaleness);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setStaleness(SYMBOL, newStaleness);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            oracle.stalenessPerSymbol(SYMBOL),
            newStaleness,
            "expected oracle.stalenessPerSymbol(SYMBOL) to equal newStaleness"
        );
    }

    function test_fuzz_setStaleness_revertsWith_MixedPriceOracle_Unauthorized(uint256 newStaleness) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newStaleness = bound(newStaleness, 1, 30 days);
        MockRoles newRoles = new MockRoles();
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = _config(address(api3), address(chainlink), "USD", "USD", 18);

        MixedPriceOracleV4 newOracle = new MixedPriceOracleV4(symbols, configs, address(newRoles), 1 days);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        newOracle.setStaleness(SYMBOL, newStaleness);
    }

    ////////////////////////////////////////////////////////////
    //                        setConfig                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setConfig_success(uint8 newUnderlyingDecimals, bool useEthSymbol) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newUnderlyingDecimals = uint8(bound(newUnderlyingDecimals, 4, 18));
        string memory toSymbol = useEthSymbol ? "ETH" : "USD";
        MixedPriceOracleV4.PriceConfig memory config =
            _config(address(api3), address(chainlink), toSymbol, toSymbol, newUnderlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);
        oracle.setConfig(SYMBOL, config);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (
            address api3Feed,
            address chainlinkFeed,
            string memory api3ToSymbol,
            string memory chainlinkToSymbol,
            uint256 storedUnderlyingDecimals
        ) = oracle.configs(SYMBOL);
        assertEq(api3Feed, address(api3), "expected api3Feed to equal address(api3)");
        assertEq(chainlinkFeed, address(chainlink), "expected chainlinkFeed to equal address(chainlink)");
        assertEq(api3ToSymbol, toSymbol, "expected api3ToSymbol to equal toSymbol");
        assertEq(chainlinkToSymbol, toSymbol, "expected chainlinkToSymbol to equal toSymbol");
        assertEq(
            storedUnderlyingDecimals,
            newUnderlyingDecimals,
            "expected storedUnderlyingDecimals to equal newUnderlyingDecimals"
        );
    }

    function test_fuzz_setConfig_revertsWith_MixedPriceOracle_InvalidConfig(uint8 underlyingDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        MixedPriceOracleV4.PriceConfig memory config =
            _config(address(0), address(chainlink), "USD", "USD", underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_InvalidConfig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);
    }

    ////////////////////////////////////////////////////////////
    //                    setMaxPriceDelta                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setMaxPriceDelta_success_updatesAndEmits(uint256 newVal) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newVal = bound(newVal, 0, oracle.PRICE_DELTA_EXP());
        uint256 oldVal = oracle.maxPriceDelta();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceDeltaUpdated(oldVal, newVal);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setMaxPriceDelta(newVal);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.maxPriceDelta(), newVal, "expected oracle.maxPriceDelta() to equal newVal");
    }

    function test_fuzz_setMaxPriceDelta_revertsWith_MixedPriceOracle_DeltaTooHigh(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        delta = bound(delta, oracle.PRICE_DELTA_EXP() + 1, oracle.PRICE_DELTA_EXP() + 1e6);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setMaxPriceDelta(delta);
    }

    ////////////////////////////////////////////////////////////
    //                 setSymbolMaxPriceDelta                 //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setSymbolMaxPriceDelta_success_updatesAndEmits(uint256 newVal) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        newVal = bound(newVal, 0, oracle.PRICE_DELTA_EXP());

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(0, newVal, SYMBOL);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(newVal, SYMBOL);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.deltaPerSymbol(SYMBOL), newVal, "expected oracle.deltaPerSymbol(SYMBOL) to equal newVal");
    }

    function test_fuzz_setSymbolMaxPriceDelta_revertsWith_MixedPriceOracle_DeltaTooHigh(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        delta = bound(delta, oracle.PRICE_DELTA_EXP() + 1, oracle.PRICE_DELTA_EXP() + 1e6);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(delta, SYMBOL);
    }

    ////////////////////////////////////////////////////////////
    //                         getPrice                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getPrice_revertsWith_MixedPriceOracle_MissingFeed(uint8 seed) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string memory missing = seed % 2 == 0 ? "MISSING" : "NOPE";
        token.setSymbol(missing);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_MissingFeed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_fuzz_getPrice_success_usesApi3WhenChainlinkMissing(uint64 rawPrice) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        rawPrice = uint64(bound(rawPrice, 1, type(uint64).max));
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(0), "USD", "USD", 18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);

        api3.setPrice(int256(uint256(rawPrice)));
        api3.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = uint256(rawPrice) * 10 ** (18 - api3.decimals());
        assertEq(price, expected, "expected price to equal expected");
    }

    function test_fuzz_getPrice_revertsWith_MixedPriceOracle_ApiV3StalePrice_whenChainlinkMissing(uint256 staleDelta)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        staleDelta = bound(staleDelta, 1 days + 1, 30 days);
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(0), "USD", "USD", 18);

        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);
        oracle.setConfig(SYMBOL, config);

        api3.setUpdatedAt(block.timestamp - staleDelta);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ApiV3StalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_fuzz_getPrice_success_usesChainlinkWhenApi3Stale(uint64 api3Raw, uint64 chainlinkRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        api3Raw = uint64(bound(api3Raw, 1, type(uint64).max));
        chainlinkRaw = uint64(bound(chainlinkRaw, 1, type(uint64).max));

        api3.setPrice(int256(uint256(api3Raw)));
        chainlink.setPrice(int256(uint256(chainlinkRaw)));
        api3.setUpdatedAt(block.timestamp - 2 days);
        chainlink.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 expected = uint256(chainlinkRaw) * 10 ** (18 - chainlink.decimals());
        assertEq(price, expected, "expected price to equal expected");
    }

    function test_fuzz_getPrice_revertsWith_MixedPriceOracle_ChainlinkStalePrice_whenApi3StaleAndChainlinkStale(uint256 staleDelta)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        staleDelta = bound(staleDelta, 1 days + 1, 30 days);
        api3.setUpdatedAt(block.timestamp - staleDelta);
        chainlink.setUpdatedAt(block.timestamp - staleDelta);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ChainlinkStalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_fuzz_getPrice_success_usesChainlinkWhenDeltaTooHigh(uint64 chainlinkRaw, uint16 deltaSymbol)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 maxDelta = oracle.PRICE_DELTA_EXP();
        uint256 upper = maxDelta > 1 ? maxDelta - 1 : 1;
        if (upper > type(uint16).max) {
            upper = type(uint16).max;
        }
        deltaSymbol = uint16(bound(deltaSymbol, 1, upper));
        chainlinkRaw = uint64(bound(chainlinkRaw, oracle.PRICE_DELTA_EXP(), 1e12));

        uint256 newDelta = deltaSymbol;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(0, newDelta, SYMBOL);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(newDelta, SYMBOL);

        uint256 diff = (uint256(chainlinkRaw) * (uint256(deltaSymbol) + 1)) / oracle.PRICE_DELTA_EXP() + 1;
        uint256 api3Raw = uint256(chainlinkRaw) + diff;
        api3.setPrice(int256(api3Raw));
        chainlink.setPrice(int256(uint256(chainlinkRaw)));
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = uint256(chainlinkRaw) * 10 ** (18 - chainlink.decimals());
        assertEq(price, expected, "expected price to equal expected");
    }

    function test_fuzz_getPrice_success_usesApi3WhenDeltaWithinThreshold(uint64 chainlinkRaw, uint16 deltaSymbol)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        deltaSymbol = uint16(bound(deltaSymbol, 1, oracle.PRICE_DELTA_EXP()));
        chainlinkRaw = uint64(bound(chainlinkRaw, 1, type(uint64).max));

        uint256 newDelta = deltaSymbol;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(0, newDelta, SYMBOL);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(newDelta, SYMBOL);

        uint256 diff = (uint256(chainlinkRaw) * uint256(deltaSymbol)) / oracle.PRICE_DELTA_EXP();
        uint256 api3Raw = uint256(chainlinkRaw) + diff;
        api3.setPrice(int256(api3Raw));
        chainlink.setPrice(int256(uint256(chainlinkRaw)));
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = api3Raw * 10 ** (18 - api3.decimals());
        assertEq(price, expected, "expected price to equal expected");
    }

    ////////////////////////////////////////////////////////////
    //                   getUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getUnderlyingPrice_success(uint8 underlyingDecimals, uint64 rawPrice) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        rawPrice = uint64(bound(rawPrice, 1, type(uint64).max));

        MixedPriceOracleV4.PriceConfig memory config =
            _config(address(api3), address(chainlink), "USD", "USD", underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);
        oracle.setConfig(SYMBOL, config);

        api3.setPrice(int256(uint256(rawPrice)));
        chainlink.setPrice(int256(uint256(rawPrice)));
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getUnderlyingPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 priceUsd = uint256(rawPrice) * 10 ** (18 - api3.decimals());
        uint256 expected = priceUsd * 10 ** (18 - underlyingDecimals);
        assertEq(price, expected, "expected price to equal expected");
    }

    ////////////////////////////////////////////////////////////
    //                    chained symbols                     //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getPrice_success_handlesChainedSymbols(uint64 ethRaw, uint64 weEthRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ethRaw = uint64(bound(ethRaw, 1, type(uint64).max));
        weEthRaw = uint64(bound(weEthRaw, 1, type(uint64).max));

        MockAdapter api3Eth = new MockAdapter();
        MockAdapter chainlinkEth = new MockAdapter();
        MockAdapter api3WeEth = new MockAdapter();
        MockAdapter chainlinkWeEth = new MockAdapter();

        api3Eth.setPrice(int256(uint256(ethRaw)));
        chainlinkEth.setPrice(int256(uint256(ethRaw)));
        api3WeEth.setPrice(int256(uint256(weEthRaw)));
        chainlinkWeEth.setPrice(int256(uint256(weEthRaw)));

        api3Eth.setUpdatedAt(block.timestamp);
        chainlinkEth.setUpdatedAt(block.timestamp);
        api3WeEth.setUpdatedAt(block.timestamp);
        chainlinkWeEth.setUpdatedAt(block.timestamp);

        string[] memory symbols = new string[](2);
        symbols[0] = "ETH";
        symbols[1] = "WEETH";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](2);
        configs[0] = _config(address(api3Eth), address(chainlinkEth), "USD", "USD", 18);
        configs[1] = _config(address(api3WeEth), address(chainlinkWeEth), "ETH", "ETH", 18);

        MixedPriceOracleV4 newOracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);

        MockToken localToken = new MockToken();
        localToken.setSymbol("WEETH");

        uint256 price = newOracle.getPrice(address(localToken));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 ethUsd = uint256(ethRaw) * 10 ** (18 - api3Eth.decimals());

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 weEthInEth = uint256(weEthRaw) * 10 ** (18 - api3WeEth.decimals());
        uint256 expected = (weEthInEth * ethUsd) / 1e18;
        assertEq(price, expected, "expected price to equal expected");
    }

    ////////////////////////////////////////////////////////////
    //                        fuzzing                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setMaxPriceDelta_success(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        delta = bound(delta, 0, oracle.PRICE_DELTA_EXP());
        uint256 oldVal = oracle.maxPriceDelta();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceDeltaUpdated(oldVal, delta);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setMaxPriceDelta(delta);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.maxPriceDelta(), delta, "expected oracle.maxPriceDelta() to equal delta");
    }

    function test_fuzz_setSymbolMaxPriceDelta_success(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        delta = bound(delta, 0, oracle.PRICE_DELTA_EXP());
        uint256 oldVal = oracle.deltaPerSymbol(SYMBOL);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(oldVal, delta, SYMBOL);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(delta, SYMBOL);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.deltaPerSymbol(SYMBOL), delta, "expected oracle.deltaPerSymbol(SYMBOL) to equal delta");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _config(
        address api3Feed,
        address chainlinkFeed,
        string memory api3ToSymbol,
        string memory chainlinkToSymbol,
        uint256 underlyingDecimals
    ) internal pure returns (MixedPriceOracleV4.PriceConfig memory) {
        return MixedPriceOracleV4.PriceConfig({
            api3Feed: api3Feed,
            chainlinkFeed: chainlinkFeed,
            api3ToSymbol: api3ToSymbol,
            chainlinkToSymbol: chainlinkToSymbol,
            underlyingDecimals: underlyingDecimals
        });
    }
}
