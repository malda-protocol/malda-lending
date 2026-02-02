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

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_MixedPriceOracle_AddressNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = _config(address(api3), address(chainlink), "USD", "USD", 18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new MixedPriceOracleV4(symbols, configs, address(0), 1 days);
    }

    ////////////////////////////////////////////////////////////
    //                      setStaleness                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setStaleness_success_updatesMappingAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 newStaleness = 1234;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.StalenessUpdated(SYMBOL, newStaleness);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setStaleness(SYMBOL, newStaleness);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.stalenessPerSymbol(SYMBOL), newStaleness);
    }

    function test_unit_setStaleness_revertsWith_MixedPriceOracle_Unauthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockRoles newRoles = new MockRoles();
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = _config(address(api3), address(chainlink), "USD", "USD", 18);

        MixedPriceOracleV4 newOracle = new MixedPriceOracleV4(symbols, configs, address(newRoles), 1 days);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        newOracle.setStaleness(SYMBOL, 1234);
    }

    ////////////////////////////////////////////////////////////
    //                        setConfig                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setConfig_success_updatesMappingAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(chainlink), "USD", "USD", 6);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (
            address api3Feed,
            address chainlinkFeed,
            string memory api3ToSymbol,
            string memory chainlinkToSymbol,
            uint256 underlyingDecimals
        ) = oracle.configs(SYMBOL);
        assertEq(api3Feed, address(api3));
        assertEq(chainlinkFeed, address(chainlink));
        assertEq(api3ToSymbol, "USD");
        assertEq(chainlinkToSymbol, "USD");
        assertEq(underlyingDecimals, 6);
    }

    function test_unit_setConfig_revertsWith_MixedPriceOracle_InvalidConfig() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MixedPriceOracleV4.PriceConfig memory config = _config(address(0), address(chainlink), "USD", "USD", 18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_InvalidConfig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);
    }

    ////////////////////////////////////////////////////////////
    //                    setMaxPriceDelta                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setMaxPriceDelta_success_updatesAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 oldVal = oracle.maxPriceDelta();
        uint256 newVal = 500;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceDeltaUpdated(oldVal, newVal);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setMaxPriceDelta(newVal);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.maxPriceDelta(), newVal);
    }

    function test_unit_setMaxPriceDelta_revertsWith_MixedPriceOracle_DeltaTooHigh() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 delta = oracle.PRICE_DELTA_EXP() + 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setMaxPriceDelta(delta);
    }

    ////////////////////////////////////////////////////////////
    //                 setSymbolMaxPriceDelta                 //
    ////////////////////////////////////////////////////////////

    function test_unit_setSymbolMaxPriceDelta_success_updatesAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 newVal = 400;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(0, newVal, SYMBOL);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(newVal, SYMBOL);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.deltaPerSymbol(SYMBOL), newVal);
    }

    function test_unit_setSymbolMaxPriceDelta_revertsWith_MixedPriceOracle_DeltaTooHigh() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 delta = oracle.PRICE_DELTA_EXP() + 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(delta, SYMBOL);
    }

    ////////////////////////////////////////////////////////////
    //                         getPrice                       //
    ////////////////////////////////////////////////////////////

    function test_unit_getPrice_revertsWith_MixedPriceOracle_MissingFeed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        token.setSymbol("MISSING");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_MissingFeed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_success_usesApi3WhenChainlinkMissing() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(0), "USD", "USD", 18);

        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);
        oracle.setConfig(SYMBOL, config);

        api3.setPrice(123e8);
        api3.setUpdatedAt(block.timestamp);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(price, 123e18);
    }

    function test_unit_getPrice_revertsWith_MixedPriceOracle_ApiV3StalePrice_whenChainlinkMissing() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(0), "USD", "USD", 18);

        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);
        oracle.setConfig(SYMBOL, config);

        api3.setUpdatedAt(block.timestamp - 2 days);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ApiV3StalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_success_usesChainlinkWhenApi3Stale() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        api3.setPrice(100e8);
        chainlink.setPrice(110e8);
        api3.setUpdatedAt(block.timestamp - 2 days);
        chainlink.setUpdatedAt(block.timestamp);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(price, 110e18);
    }

    function test_unit_getPrice_revertsWith_MixedPriceOracle_ChainlinkStalePrice_whenApi3StaleAndChainlinkStale()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        api3.setUpdatedAt(block.timestamp - 2 days);
        chainlink.setUpdatedAt(block.timestamp - 2 days);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ChainlinkStalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_success_usesChainlinkWhenDeltaTooHigh() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 newDelta = 1;
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(0, newDelta, SYMBOL);
        oracle.setSymbolMaxPriceDelta(newDelta, SYMBOL);

        api3.setPrice(100e8);
        chainlink.setPrice(120e8);
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(price, 120e18);
    }

    function test_unit_getPrice_success_usesApi3WhenDeltaWithinThreshold() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 newDelta = 25_000;
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(0, newDelta, SYMBOL);
        oracle.setSymbolMaxPriceDelta(newDelta, SYMBOL);

        api3.setPrice(100e8);
        chainlink.setPrice(105e8);
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(price, 100e18);
    }

    ////////////////////////////////////////////////////////////
    //                   getUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_unit_getUnderlyingPrice_success_scalesUnderlyingDecimals() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MixedPriceOracleV4.PriceConfig memory config = _config(address(api3), address(chainlink), "USD", "USD", 6);

        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.ConfigSet(SYMBOL, config);
        oracle.setConfig(SYMBOL, config);

        api3.setPrice(2e8);
        chainlink.setPrice(2e8);
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getUnderlyingPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(price, 2e30);
    }

    ////////////////////////////////////////////////////////////
    //                    chained symbols                     //
    ////////////////////////////////////////////////////////////

    function test_unit_getPrice_success_handlesChainedSymbols() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockAdapter api3Eth = new MockAdapter();
        MockAdapter chainlinkEth = new MockAdapter();
        MockAdapter api3WeEth = new MockAdapter();
        MockAdapter chainlinkWeEth = new MockAdapter();

        api3Eth.setPrice(2_000e8);
        chainlinkEth.setPrice(2_000e8);
        api3WeEth.setPrice(2e8);
        chainlinkWeEth.setPrice(2e8);

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

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = newOracle.getPrice(address(localToken));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(price, 4_000e18);
    }

    ////////////////////////////////////////////////////////////
    //                        fuzzing                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setMaxPriceDelta_success(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(delta <= oracle.PRICE_DELTA_EXP());
        uint256 oldVal = oracle.maxPriceDelta();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceDeltaUpdated(oldVal, delta);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setMaxPriceDelta(delta);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.maxPriceDelta(), delta);
    }

    function test_fuzz_setSymbolMaxPriceDelta_success(uint256 delta) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(delta <= oracle.PRICE_DELTA_EXP());
        uint256 oldVal = oracle.deltaPerSymbol(SYMBOL);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV4.PriceSymbolDeltaUpdated(oldVal, delta, SYMBOL);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setSymbolMaxPriceDelta(delta, SYMBOL);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.deltaPerSymbol(SYMBOL), delta);
    }
}
