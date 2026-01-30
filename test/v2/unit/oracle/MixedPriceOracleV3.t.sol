// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {Roles} from "src/Roles.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {MockV3Feed, MockV3MToken} from "test/v2/mocks/oracles/OracleV3Mocks.t.sol";

contract MixedPriceOracleV3Test is BaseTest {
    Roles internal roles;

    function setUp() public override {
        super.setUp();
        roles = new Roles(address(this));
        roles.allowFor(address(this), roles.GUARDIAN_ORACLE(), true);
    }

    function _deployOracle(address feed, string memory symbol, uint256 underlyingDecimals)
        internal
        returns (MixedPriceOracleV3)
    {
        string[] memory symbols = new string[](1);
        symbols[0] = symbol;
        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] =
            IDefaultAdapter.PriceConfig({defaultFeed: feed, toSymbol: "USD", underlyingDecimals: underlyingDecimals});

        return new MixedPriceOracleV3(symbols, configs, address(roles), 1 days);
    }

    ////////////////////////////////////////////////////////////
    //                      SetStaleness                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setStaleness_success_updatesMapping() external {
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);

        oracle.setStaleness("MOCK", 1234);
        assertEq(oracle.stalenessPerSymbol("MOCK"), 1234);
    }

    function test_unit_setStaleness_revertsWith_MixedPriceOracle_Unauthorized() external {
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);

        vm.prank(users.bob);
        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_Unauthorized.selector);
        oracle.setStaleness("MOCK", 1234);
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_MixedPriceOracle_AddressNotValid() external {
        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";
        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = IDefaultAdapter.PriceConfig({defaultFeed: address(0), toSymbol: "USD", underlyingDecimals: 18});

        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_AddressNotValid.selector);
        new MixedPriceOracleV3(symbols, configs, address(0), 1 days);
    }

    ////////////////////////////////////////////////////////////
    //                       SetConfig                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setConfig_revertsWith_MixedPriceOracle_InvalidConfig() external {
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);

        IDefaultAdapter.PriceConfig memory config =
            IDefaultAdapter.PriceConfig({defaultFeed: address(0), toSymbol: "USD", underlyingDecimals: 18});

        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);
        oracle.setConfig("MOCK", config);
    }

    ////////////////////////////////////////////////////////////
    //                        GetPrice                        //
    ////////////////////////////////////////////////////////////

    function test_unit_getPrice_revertsWith_MixedPriceOracle_InvalidConfig_variant2() external {
        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";
        IDefaultAdapter.PriceConfig[] memory configs = new IDefaultAdapter.PriceConfig[](1);
        configs[0] = IDefaultAdapter.PriceConfig({defaultFeed: address(0), toSymbol: "USD", underlyingDecimals: 18});

        MixedPriceOracleV3 oracle = new MixedPriceOracleV3(symbols, configs, address(roles), 1 days);
        MockV3MToken token = new MockV3MToken("MOCK", address(0));

        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_revertsWith_MixedPriceOracle_InvalidPrice() external {
        MockV3Feed feed = new MockV3Feed(8, 0);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);
        MockV3MToken token = new MockV3MToken("MOCK", address(0));

        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidPrice.selector);
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_revertsWith_MixedPriceOracle_StalePrice() external {
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);
        MockV3MToken token = new MockV3MToken("MOCK", address(0));

        vm.warp(100);
        oracle.setStaleness("MOCK", 1);
        feed.setUpdatedAt(block.timestamp - 2);

        vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_StalePrice.selector);
        oracle.getPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //                        Configs                         //
    ////////////////////////////////////////////////////////////

    function test_unit_configs_success_updatesMapping_variant2() external {
        MockV3Feed feed = new MockV3Feed(8, 1e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);

        MockV3Feed newFeed = new MockV3Feed(8, 2e8);
        IDefaultAdapter.PriceConfig memory config =
            IDefaultAdapter.PriceConfig({defaultFeed: address(newFeed), toSymbol: "USD", underlyingDecimals: 6});

        oracle.setConfig("MOCK", config);
        (address storedFeed, string memory toSymbol, uint256 decimals) = oracle.configs("MOCK");
        assertEq(storedFeed, address(newFeed));
        assertEq(toSymbol, "USD");
        assertEq(decimals, 6);
    }

    ////////////////////////////////////////////////////////////
    //                        GetPrice                        //
    ////////////////////////////////////////////////////////////

    function test_unit_getPrice_success_returnsScaledPrice() external {
        MockV3Feed feed = new MockV3Feed(8, 2_500e8);
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);
        MockV3MToken token = new MockV3MToken("MOCK", address(0));

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 2_500e18);
    }

    function test_fuzz_getPrice_success_scales(uint8 feedDecimals, uint64 rawPrice) external {
        vm.assume(feedDecimals <= 18);
        vm.assume(rawPrice > 0);

        MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
        MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);
        MockV3MToken token = new MockV3MToken("MOCK", address(0));

        uint256 price = oracle.getPrice(address(token));
        uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        assertEq(price, expected);
    }
}
