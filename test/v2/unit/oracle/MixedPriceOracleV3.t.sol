// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
import {Roles} from "src/Roles.sol";

import {MockV3Feed, MockV3MToken, MockV3Token} from "test/v2/mocks/oracles/OracleV3Mocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract MixedPriceOracleV3Test is BaseTest {
    string internal constant SYMBOL = "MOCK";

    Roles internal roles;

    function setUp() public override {
        super.setUp();
        roles = new Roles(address(this));
        roles.allowFor(address(this), roles.GUARDIAN_ORACLE(), true);
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _deployOracle(address feed, string memory symbol, uint256 underlyingDecimals)
        internal
        returns (MixedPriceOracleV3)
    {
        string[] memory symbols = new string[](1);
        symbols[0] = symbol;

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = _config(feed, underlyingDecimals);

        return new MixedPriceOracleV3(symbols, configs, address(roles), 1 days);
    }

    function _deployOracleWithConfig(string memory symbol, IDefaultAdapter.PriceConfig memory config)
        internal
        returns (MixedPriceOracleV3)
    {
        string[] memory symbols = new string[](1);
        symbols[0] = symbol;

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = config;

        return new MixedPriceOracleV3(symbols, configs, address(roles), 1 days);
    }

    function _config(address feed, uint256 underlyingDecimals)
        internal
        pure
        returns (IDefaultAdapter.PriceConfig memory)
    {
        return IDefaultAdapter.PriceConfig({defaultFeed: feed, toSymbol: "USD", underlyingDecimals: underlyingDecimals});
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_MixedPriceOracle_AddressNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = _config(address(0), 18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new MixedPriceOracleV3(symbols, configs, address(0), 1 days);
    }

    ////////////////////////////////////////////////////////////
    //                      setStaleness                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setStaleness_success_updatesMappingAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV3.StalenessUpdated(SYMBOL, 1234);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setStaleness(SYMBOL, 1234);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(oracle.stalenessPerSymbol(SYMBOL), 1234);
    }

    function test_unit_setStaleness_revertsWith_MixedPriceOracle_Unauthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        oracle.setStaleness(SYMBOL, 1234);
    }

    ////////////////////////////////////////////////////////////
    //                        setConfig                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setConfig_success_updatesMappingAndEmits() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        MockV3Feed newFeed = new MockV3Feed(8, 2e8);
        IDefaultAdapter.PriceConfig memory config = _config(address(newFeed), 6);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV3.ConfigSet(SYMBOL, config);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (address storedFeed, string memory toSymbol, uint256 decimals) = oracle.configs(SYMBOL);
        assertEq(storedFeed, address(newFeed));
        assertEq(toSymbol, "USD");
        assertEq(decimals, 6);
    }

    function test_unit_setConfig_revertsWith_MixedPriceOracle_InvalidConfig() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        IDefaultAdapter.PriceConfig memory config = _config(address(0), 18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);
    }

    ////////////////////////////////////////////////////////////
    //                         getPrice                       //
    ////////////////////////////////////////////////////////////

    function test_unit_getPrice_revertsWith_MixedPriceOracle_InvalidConfig() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IDefaultAdapter.PriceConfig memory config = _config(address(0), 18);
        MixedPriceOracleV3 oracle = _deployOracleWithConfig(SYMBOL, config);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_revertsWith_MixedPriceOracle_InvalidPrice() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 0);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_revertsWith_MixedPriceOracle_StalePrice() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        vm.warp(100);
        oracle.setStaleness(SYMBOL, 1);
        feed.setUpdatedAt(block.timestamp - 2);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_StalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_success_returnsScaledPrice() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 2_500e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(price, 2_500e18);
    }

    function test_fuzz_getPrice_success_scales(uint8 feedDecimals, uint64 rawPrice) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(feedDecimals <= 18);
        vm.assume(rawPrice > 0);

        MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        assertEq(price, expected);
    }

    ////////////////////////////////////////////////////////////
    //                   getUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getUnderlyingPrice_success_scales(uint8 feedDecimals, uint8 underlyingDecimals, uint64 rawPrice)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(feedDecimals <= 18);
        vm.assume(underlyingDecimals <= 18);
        vm.assume(rawPrice > 0);

        MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, underlyingDecimals);

        MockV3Token underlying = new MockV3Token(SYMBOL);
        MockV3MToken token = new MockV3MToken("mMOCK", address(underlying));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getUnderlyingPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 priceUsd = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        uint256 expected = priceUsd * 10 ** (18 - underlyingDecimals);
        assertEq(price, expected);
    }
}
