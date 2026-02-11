// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";

import {MockAdapter, MockRoles, MockToken} from "test/v2/mocks/oracles/OracleV4Mocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract MixedPriceOracleV4Test is BaseTest {
    string internal constant SYMBOL = "MOCK";
    uint256 internal constant DEFAULT_STALENESS = 1 days;

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

        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(chainlink), "USD", "USD", 18);
        oracle = _deployOracleWithConfig(SYMBOL, config, address(roles), DEFAULT_STALENESS);
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

    function test_unit_constructor_revertsWith_CommonLib_LengthMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
    }

    function test_fuzz_constructor_success(uint8 underlyingDecimals, uint256 staleness) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        staleness = bound(staleness, 1, 30 days);
        MixedPriceOracleV4.PriceConfig memory config =
            _config(address(api3), address(chainlink), "USD", "USD", underlyingDecimals);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        MixedPriceOracleV4 newOracle = _deployOracleWithConfig(SYMBOL, config, address(roles), staleness);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (
            address api3Feed,
            address chainlinkFeed,
            string memory api3ToSymbol,
            string memory chainlinkToSymbol,
            uint256 decimals
        ) = newOracle.configs(SYMBOL);
        assertEq(api3Feed, address(api3), "expected api3Feed to equal address(api3)");
        assertEq(chainlinkFeed, address(chainlink), "expected chainlinkFeed to equal address(chainlink)");
        assertEq(api3ToSymbol, "USD", "expected api3ToSymbol to equal USD");
        assertEq(chainlinkToSymbol, "USD", "expected chainlinkToSymbol to equal USD");
        assertEq(decimals, underlyingDecimals, "expected decimals to equal underlyingDecimals");
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
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(chainlink), "USD", "USD", 18);
        MixedPriceOracleV4 newOracle = _deployOracleWithConfig(SYMBOL, config, address(newRoles), DEFAULT_STALENESS);

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

    function test_fuzz_setConfig_revertsWith_MixedPriceOracle_Unauthorized(uint8 underlyingDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        MockRoles noAccessRoles = new MockRoles();

        MixedPriceOracleV4.PriceConfig memory initialConfig =
            _config(address(api3), address(chainlink), "USD", "USD", 18);
        MixedPriceOracleV4 newOracle =
            _deployOracleWithConfig(SYMBOL, initialConfig, address(noAccessRoles), DEFAULT_STALENESS);

        MixedPriceOracleV4.PriceConfig memory config =
            _config(address(api3), address(chainlink), "USD", "USD", underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        newOracle.setConfig(SYMBOL, config);
    }

    ////////////////////////////////////////////////////////////
    //                    setMaxPriceDelta                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setMaxPriceDelta_success(uint256 newVal) external {
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

    function test_fuzz_setMaxPriceDelta_revertsWith_MixedPriceOracle_Unauthorized(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        delta = bound(delta, 0, oracle.PRICE_DELTA_EXP());
        MockRoles noAccessRoles = new MockRoles();

        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(chainlink), "USD", "USD", 18);
        MixedPriceOracleV4 newOracle =
            _deployOracleWithConfig(SYMBOL, config, address(noAccessRoles), DEFAULT_STALENESS);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        newOracle.setMaxPriceDelta(delta);
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

    function test_fuzz_setSymbolMaxPriceDelta_revertsWith_MixedPriceOracle_Unauthorized(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        delta = bound(delta, 0, oracle.PRICE_DELTA_EXP());
        MockRoles noAccessRoles = new MockRoles();

        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(chainlink), "USD", "USD", 18);
        MixedPriceOracleV4 newOracle =
            _deployOracleWithConfig(SYMBOL, config, address(noAccessRoles), DEFAULT_STALENESS);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        newOracle.setSymbolMaxPriceDelta(delta, SYMBOL);
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

    function test_unit_getPrice_success_usesApi3_whenSymbolStalenessOverridesGlobal() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 staleWindow = 2 days;
        uint256 api3Raw = 2_000 * 1e8;
        uint256 chainlinkRaw = 1_999 * 1e8;

        oracle.setStaleness(SYMBOL, staleWindow);
        api3.setPrice(int256(api3Raw));
        chainlink.setPrice(int256(chainlinkRaw));
        api3.setUpdatedAt(block.timestamp - 1 days);
        chainlink.setUpdatedAt(block.timestamp - 1 days);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = api3Raw * 10 ** (18 - api3.decimals());
        assertEq(price, expected, "expected price to equal expected");
    }

    // NOTE (as of 2026-02-11): unreachable invariant.
    // When a secondary feed is configured and API3 is stale, flow enters the chainlink fallback branch;
    // the late API3 stale require path is therefore unreachable in this stale-API3 configuration.
    function test_unit_unreachableInvariant_getPrice_staleApi3UsesChainlinkFallback() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 api3Raw = 2_100e8;
        uint256 chainlinkRaw = 2_000e8;
        api3.setPrice(int256(api3Raw));
        chainlink.setPrice(int256(chainlinkRaw));
        api3.setUpdatedAt(block.timestamp - 2 days);
        chainlink.setUpdatedAt(block.timestamp);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = chainlinkRaw * 10 ** (18 - chainlink.decimals());
        assertEq(price, expected, "expected price to equal expected");
    }

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

    function test_unit_getPrice_success_handlesChainedSymbols_usesOldestParentUpdate() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockAdapter api3Eth = new MockAdapter();
        MockAdapter chainlinkEth = new MockAdapter();
        MockAdapter api3WeEth = new MockAdapter();
        MockAdapter chainlinkWeEth = new MockAdapter();

        api3Eth.setPrice(2_000e8);
        chainlinkEth.setPrice(2_000e8);
        api3WeEth.setPrice(1e8);
        chainlinkWeEth.setPrice(1e8);

        uint256 oldTs = block.timestamp - 1 days;
        uint256 freshTs = block.timestamp;
        api3Eth.setUpdatedAt(oldTs);
        chainlinkEth.setUpdatedAt(oldTs);
        api3WeEth.setUpdatedAt(freshTs);
        chainlinkWeEth.setUpdatedAt(freshTs);

        string[] memory symbols = new string[](2);
        symbols[0] = "ETH";
        symbols[1] = "WEETH";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](2);
        configs[0] = _config(address(api3Eth), address(chainlinkEth), "USD", "USD", 18);
        configs[1] = _config(address(api3WeEth), address(chainlinkWeEth), "ETH", "ETH", 18);

        MixedPriceOracleV4 newOracle = new MixedPriceOracleV4(symbols, configs, address(roles), 2 days);

        MockToken localToken = new MockToken();
        localToken.setSymbol("WEETH");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = newOracle.getPrice(address(localToken));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 ethUsd = 2_000e18;
        uint256 weEthInEth = 1e18;
        uint256 expected = (weEthInEth * ethUsd) / 1e18;
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

    function test_fuzz_getUnderlyingPrice_revertsWith_MixedPriceOracle_MissingFeed(uint8 underlyingDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        MixedPriceOracleV4.PriceConfig memory config =
            _config(address(0), address(chainlink), "USD", "USD", underlyingDecimals);
        MixedPriceOracleV4 newOracle = _deployOracleWithConfig(SYMBOL, config, address(roles), DEFAULT_STALENESS);

        token.setUnderlying(address(token));
        token.setSymbol(SYMBOL);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_MissingFeed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        newOracle.getUnderlyingPrice(address(token));
    }

    function test_fuzz_getUnderlyingPrice_revertsWith_MixedPriceOracle_ApiV3StalePrice_whenChainlinkMissing(uint256 staleDelta)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        staleDelta = bound(staleDelta, DEFAULT_STALENESS + 1, DEFAULT_STALENESS + 30 days);
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(0), "USD", "USD", 18);

        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);
        oracle.setConfig(SYMBOL, config);

        api3.setUpdatedAt(block.timestamp - staleDelta);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ApiV3StalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getUnderlyingPrice(address(token));
    }

    function test_fuzz_getUnderlyingPrice_revertsWith_MixedPriceOracle_ChainlinkStalePrice_whenApi3Stale(uint256 staleDelta)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        staleDelta = bound(staleDelta, DEFAULT_STALENESS + 1, DEFAULT_STALENESS + 30 days);
        api3.setUpdatedAt(block.timestamp - staleDelta);
        chainlink.setUpdatedAt(block.timestamp - staleDelta);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ChainlinkStalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getUnderlyingPrice(address(token));
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

    function _deployOracleWithConfig(
        string memory symbol,
        MixedPriceOracleV4.PriceConfig memory config,
        address rolesAddr,
        uint256 staleness
    ) internal returns (MixedPriceOracleV4) {
        string[] memory symbols = new string[](1);
        symbols[0] = symbol;

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = config;

        MixedPriceOracleV4 newOracle = new MixedPriceOracleV4(symbols, configs, rolesAddr, staleness);

        assertEq(address(newOracle.ROLES()), rolesAddr, "expected newOracle.ROLES() to equal rolesAddr");
        assertEq(newOracle.STALENESS_PERIOD(), staleness, "expected newOracle.STALENESS_PERIOD() to equal staleness");

        (
            address api3Feed,
            address chainlinkFeed,
            string memory api3ToSymbol,
            string memory chainlinkToSymbol,
            uint256 storedUnderlyingDecimals
        ) = newOracle.configs(symbol);

        assertEq(api3Feed, config.api3Feed, "expected api3Feed to equal config.api3Feed");
        assertEq(chainlinkFeed, config.chainlinkFeed, "expected chainlinkFeed to equal config.chainlinkFeed");
        assertEq(api3ToSymbol, config.api3ToSymbol, "expected api3ToSymbol to equal config.api3ToSymbol");
        assertEq(
            chainlinkToSymbol, config.chainlinkToSymbol, "expected chainlinkToSymbol to equal config.chainlinkToSymbol"
        );
        assertEq(
            storedUnderlyingDecimals,
            config.underlyingDecimals,
            "expected storedUnderlyingDecimals to equal config.underlyingDecimals"
        );

        return newOracle;
    }
}
