// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
import {Roles} from "src/Roles.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";

import {MockV3Feed, MockV3MToken, MockV3Token} from "test/v2/mocks/oracles/OracleV3Mocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract MixedPriceOracleV3Test is BaseTest {
    string internal constant SYMBOL = "MOCK";
    uint256 internal constant DEFAULT_STALENESS = 1 days;

    Roles internal roles;

    function setUp() public override {
        super.setUp();
        roles = new Roles(address(this));
        roles.allowFor(address(this), roles.GUARDIAN_ORACLE(), true);
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

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = _config(address(0), underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new MixedPriceOracleV3(symbols, configs, address(0), staleness);
    }

    function test_unit_constructor_revertsWith_CommonLib_LengthMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.CommonLib_LengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new MixedPriceOracleV3(symbols, configs, address(roles), 1 days);
    }

    function test_fuzz_constructor_success(uint8 underlyingDecimals, uint256 staleness) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        staleness = bound(staleness, 1, 30 days);

        MockV3Feed feed = new MockV3Feed(8, 1e8);

        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL;

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = _config(address(feed), underlyingDecimals);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        MixedPriceOracleV3 oracle = new MixedPriceOracleV3(symbols, configs, address(roles), staleness);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(oracle.ROLES()), address(roles), "expected oracle.ROLES() to equal address(roles)");
        assertEq(oracle.STALENESS_PERIOD(), staleness, "expected oracle.STALENESS_PERIOD() to equal staleness");

        (address defaultFeed, string memory toSymbol, uint256 storedUnderlyingDecimals) = oracle.configs(SYMBOL);
        assertEq(defaultFeed, address(feed), "expected defaultFeed to equal address(feed)");
        assertEq(toSymbol, "USD", "expected toSymbol to equal USD");
        assertEq(
            storedUnderlyingDecimals,
            underlyingDecimals,
            "expected storedUnderlyingDecimals to equal underlyingDecimals"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      setStaleness                      //
    ////////////////////////////////////////////////////////////
    function test_fuzz_setStaleness_revertsWith_MixedPriceOracle_Unauthorized(uint256 newStaleness) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        newStaleness = bound(newStaleness, 1, 30 days);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        oracle.setStaleness(SYMBOL, newStaleness);
    }

    function test_fuzz_setStaleness_success(uint256 newStaleness) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        newStaleness = bound(newStaleness, 1, 30 days);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV3.StalenessUpdated(SYMBOL, newStaleness);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setStaleness(SYMBOL, newStaleness);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            oracle.stalenessPerSymbol(SYMBOL),
            newStaleness,
            "expected oracle.stalenessPerSymbol(SYMBOL) to equal newStaleness"
        );
    }

    ////////////////////////////////////////////////////////////
    //                        setConfig                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setConfig_revertsWith_MixedPriceOracle_InvalidConfig(uint8 underlyingDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        IDefaultAdapter.PriceConfig memory config = _config(address(0), underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);
    }

    function test_fuzz_setConfig_revertsWith_MixedPriceOracle_Unauthorized(uint8 underlyingDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        IDefaultAdapter.PriceConfig memory config = _config(address(feed), underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_Unauthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        oracle.setConfig(SYMBOL, config);
    }

    function test_fuzz_setConfig_success(uint8 feedDecimals, uint8 underlyingDecimals, uint64 rawPrice) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        rawPrice = uint64(bound(rawPrice, 1e6, type(uint64).max));

        MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        MockV3Feed newFeed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
        IDefaultAdapter.PriceConfig memory config = _config(address(newFeed), underlyingDecimals);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit MixedPriceOracleV3.ConfigSet(SYMBOL, config);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.setConfig(SYMBOL, config);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (address storedFeed, string memory toSymbol, uint256 decimals) = oracle.configs(SYMBOL);
        assertEq(storedFeed, address(newFeed), "expected storedFeed to equal address(newFeed)");
        assertEq(toSymbol, "USD", "output symbol is not USD");
        assertEq(decimals, underlyingDecimals, "expected decimals to equal underlyingDecimals");
    }

    ////////////////////////////////////////////////////////////
    //                         getPrice                       //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getPrice_revertsWith_MixedPriceOracle_InvalidConfig(uint8 underlyingDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        IDefaultAdapter.PriceConfig memory config = _config(address(0), underlyingDecimals);
        MixedPriceOracleV3 oracle = _deployOracleWithConfig(SYMBOL, config);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_fuzz_getPrice_revertsWith_MixedPriceOracle_InvalidPrice(uint8 feedDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        MockV3Feed feed = new MockV3Feed(feedDecimals, 0);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_fuzz_getPrice_revertsWith_MixedPriceOracle_StalePrice(uint256 staleness, uint256 staleDelta)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        staleness = bound(staleness, 1, 30 days);
        staleDelta = bound(staleDelta, staleness + 1, staleness + 30 days);

        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        uint256 nowTs = staleDelta + 1;
        vm.warp(nowTs);
        oracle.setStaleness(SYMBOL, staleness);
        feed.setUpdatedAt(nowTs - staleDelta);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_StalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_fuzz_getPrice_success_returnsScaledPrice(uint8 feedDecimals, uint64 rawPrice) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        rawPrice = uint64(bound(rawPrice, 1e6, type(uint64).max));

        MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);
        MockV3MToken token = new MockV3MToken(SYMBOL, address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        assertEq(price, expected, "expected price to equal expected");
    }

    ////////////////////////////////////////////////////////////
    //                   getUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getUnderlyingPrice_success(uint8 feedDecimals, uint8 underlyingDecimals, uint64 rawPrice)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        rawPrice = uint64(bound(rawPrice, 1, type(uint64).max));

        MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, underlyingDecimals);

        MockV3Token underlying = new MockV3Token(SYMBOL);
        MockV3MToken token = new MockV3MToken("mMOCK", address(underlying));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getUnderlyingPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 priceUsd = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        uint256 expected = priceUsd * 10 ** (18 - underlyingDecimals);
        assertEq(price, expected, "expected price to equal expected");
    }

    function test_fuzz_getUnderlyingPrice_revertsWith_MixedPriceOracle_InvalidConfig(uint8 underlyingDecimals)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        IDefaultAdapter.PriceConfig memory config = _config(address(0), underlyingDecimals);
        MixedPriceOracleV3 oracle = _deployOracleWithConfig(SYMBOL, config);
        MockV3Token underlying = new MockV3Token(SYMBOL);
        MockV3MToken token = new MockV3MToken("mMOCK", address(underlying));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getUnderlyingPrice(address(token));
    }

    function test_fuzz_getUnderlyingPrice_revertsWith_MixedPriceOracle_InvalidPrice(uint8 feedDecimals) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        MockV3Feed feed = new MockV3Feed(feedDecimals, 0);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        MockV3Token underlying = new MockV3Token(SYMBOL);
        MockV3MToken token = new MockV3MToken("mMOCK", address(underlying));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getUnderlyingPrice(address(token));
    }

    function test_fuzz_getUnderlyingPrice_revertsWith_MixedPriceOracle_StalePrice(uint256 staleness, uint256 staleDelta)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        staleness = bound(staleness, 1, 30 days);
        staleDelta = bound(staleDelta, staleness + 1, staleness + 30 days);

        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), SYMBOL, 18);

        MockV3Token underlying = new MockV3Token(SYMBOL);
        MockV3MToken token = new MockV3MToken("mMOCK", address(underlying));

        uint256 nowTs = staleDelta + 1;
        vm.warp(nowTs);
        oracle.setStaleness(SYMBOL, staleness);
        feed.setUpdatedAt(nowTs - staleDelta);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_StalePrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getUnderlyingPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _deployOracle(address feed, string memory symbol, uint256 underlyingDecimals)
        internal
        returns (MixedPriceOracleV3)
    {
        return _deployOracleWithConfig(symbol, _config(feed, underlyingDecimals));
    }

    function _deployOracleWithConfig(string memory symbol, IDefaultAdapter.PriceConfig memory config)
        internal
        returns (MixedPriceOracleV3)
    {
        string[] memory symbols = new string[](1);
        symbols[0] = symbol;

        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = config;

        MixedPriceOracleV3 oracle = new MixedPriceOracleV3(symbols, configs, address(roles), DEFAULT_STALENESS);

        assertEq(address(oracle.ROLES()), address(roles), "expected oracle.ROLES() to equal address(roles)");
        assertEq(
            oracle.STALENESS_PERIOD(),
            DEFAULT_STALENESS,
            "expected oracle.STALENESS_PERIOD() to equal DEFAULT_STALENESS"
        );
        (address defaultFeed, string memory toSymbol, uint256 storedUnderlyingDecimals) = oracle.configs(symbol);
        assertEq(defaultFeed, config.defaultFeed, "expected defaultFeed to equal config.defaultFeed");
        assertEq(toSymbol, config.toSymbol, "expected toSymbol to equal config.toSymbol");
        assertEq(
            storedUnderlyingDecimals,
            config.underlyingDecimals,
            "expected storedUnderlyingDecimals to equal config.underlyingDecimals"
        );

        return oracle;
    }

    function _config(address feed, uint256 underlyingDecimals)
        internal
        pure
        returns (IDefaultAdapter.PriceConfig memory)
    {
        return IDefaultAdapter.PriceConfig({defaultFeed: feed, toSymbol: "USD", underlyingDecimals: underlyingDecimals});
    }
}
