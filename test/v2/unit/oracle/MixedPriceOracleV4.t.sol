// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";
import {MockAdapter, MockRoles, MockToken} from "test/v2/mocks/oracles/OracleV4Mocks.t.sol";

contract MixedPriceOracleV4Test is BaseTest {
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
        symbols[0] = "MOCK";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(chainlink),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });

        oracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
        roles.allow(address(this));

        vm.warp(100 days);
    }

    ////////////////////////////////////////////////////////////
    //                       SetStaleness                       //
    ////////////////////////////////////////////////////////////

    function test_unitSetStaleness_success() public {
        oracle.setStaleness("MOCK", 1234);
        assertEq(oracle.stalenessPerSymbol("MOCK"), 1234);
    }

    function test_unitSetStaleness_revertsWith_revertWhenUnauthorized() public {
        MockRoles newRoles = new MockRoles();

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(chainlink),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });

        MixedPriceOracleV4 newOracle = new MixedPriceOracleV4(symbols, configs, address(newRoles), 1 days);

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_Unauthorized.selector);
        newOracle.setStaleness("MOCK", 1234);
    }

    ////////////////////////////////////////////////////////////
    //                       Constructor                        //
    ////////////////////////////////////////////////////////////

    function test_unitConstructor_revertsWith_revertWhenRolesZero() public {
        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(chainlink),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_AddressNotValid.selector);
        new MixedPriceOracleV4(symbols, configs, address(0), 1 days);
    }

    ////////////////////////////////////////////////////////////
    //                     SetMaxPriceDelta                     //
    ////////////////////////////////////////////////////////////

    function test_unitSetMaxPriceDelta_success() public {
        oracle.setMaxPriceDelta(500);
        assertEq(oracle.maxPriceDelta(), 500);
    }

    function test_unitSetMaxPriceDelta_revertsWith_revertWhenTooHigh() public {
        uint256 delta = oracle.PRICE_DELTA_EXP() + 1;
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);
        oracle.setMaxPriceDelta(delta);
    }

    ////////////////////////////////////////////////////////////
    //                  SetSymbolMaxPriceDelta                  //
    ////////////////////////////////////////////////////////////

    function test_unitSetSymbolMaxPriceDelta_success() public {
        oracle.setSymbolMaxPriceDelta(400, "MOCK");
        assertEq(oracle.deltaPerSymbol("MOCK"), 400);
    }

    function test_unitSetSymbolMaxPriceDelta_revertsWith_revertWhenTooHigh() public {
        uint256 delta = oracle.PRICE_DELTA_EXP() + 1;
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);
        oracle.setSymbolMaxPriceDelta(delta, "MOCK");
    }

    ////////////////////////////////////////////////////////////
    //                        SetConfig                         //
    ////////////////////////////////////////////////////////////

    function test_unitSetConfig_success() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(chainlink),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        oracle.setConfig("MOCK", cfg);
    }

    function test_unitSetConfig_revertsWith_revertWhenApi3FeedZero() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(0),
            chainlinkFeed: address(chainlink),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_InvalidConfig.selector);
        oracle.setConfig("MOCK", cfg);
    }

    function test_unitSetConfig_success_allowsChainlinkFeedZero() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(0),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });

        oracle.setConfig("MOCK", cfg);
        (, address chainlinkFeed,,,) = oracle.configs("MOCK");
        assertEq(chainlinkFeed, address(0));
    }

    ////////////////////////////////////////////////////////////
    //                         GetPrice                         //
    ////////////////////////////////////////////////////////////

    function test_unitGetPrice_success_usesApi3WhenChainlinkMissing() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(0),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        oracle.setConfig("MOCK", cfg);

        api3.setPrice(123e8);
        api3.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 123e18);
    }

    function test_unitGetPrice_revertsWith_revertWhenApi3StaleAndChainlinkMissing() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(0),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        oracle.setConfig("MOCK", cfg);

        api3.setUpdatedAt(block.timestamp - 2 days);

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ApiV3StalePrice.selector);
        oracle.getPrice(address(token));
    }

    function test_unitGetPrice_success() public {
        chainlink.setUpdatedAt(block.timestamp - 10);
        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 1e18); // since price is 1e8 and decimals = 8
    }

    function test_unitGetPrice_success_usesApi3WhenFresh() public {
        api3.setPrice(100e8);
        chainlink.setPrice(101e8);
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 100e18);
    }

    function test_unitGetPrice_revertsWith_revertWhenMissingFeed() public {
        token.setSymbol("MISSING");
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_MissingFeed.selector);
        oracle.getPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //                    GetUnderlyingPrice                    //
    ////////////////////////////////////////////////////////////

    function test_unitGetUnderlyingPrice_success() public {
        chainlink.setUpdatedAt(block.timestamp - 10);
        uint256 price = oracle.getUnderlyingPrice(address(token));
        assertEq(price, 1e18); // same as getPrice because underlyingDecimals = 18
    }

    ////////////////////////////////////////////////////////////
    //                 UseChainlinkOnApi3Stale                  //
    ////////////////////////////////////////////////////////////

    function test_unitUseChainlinkOnApi3Stale_success() public {
        api3.setUpdatedAt(block.timestamp - 2 days);
        chainlink.setPrice(2e8);
        chainlink.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 2e18);
    }

    ////////////////////////////////////////////////////////////
    //                    RevertIfBothStale                     //
    ////////////////////////////////////////////////////////////

    function test_unitRevertIfBothStale_revertsWith() public {
        api3.setUpdatedAt(block.timestamp - 2 days);
        chainlink.setUpdatedAt(block.timestamp - 2 days);

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ChainlinkStalePrice.selector);
        oracle.getPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //            FallbackToChainlinkOnDeltaTooHigh             //
    ////////////////////////////////////////////////////////////

    function test_unitFallbackToChainlinkOnDeltaTooHigh_success() public {
        // api3 = 1e8, chainlink = 3e8 -> 200% delta
        chainlink.setPrice(3e8);
        chainlink.setUpdatedAt(block.timestamp);

        oracle.setSymbolMaxPriceDelta(1500, "MOCK"); // 1.5% allowed

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 3e18);
    }

    ////////////////////////////////////////////////////////////
    //           FailsIfDeltaTooHighAndChainlinkStale           //
    ////////////////////////////////////////////////////////////

    function test_unitFailsIfDeltaTooHighAndChainlinkStale_revertsWith() public {
        chainlink.setPrice(3e8);
        chainlink.setUpdatedAt(block.timestamp - 2 days);
        oracle.setSymbolMaxPriceDelta(1500, "MOCK");

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_ChainlinkStalePrice.selector);
        oracle.getPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //                      ComposedPrice                       //
    ////////////////////////////////////////////////////////////

    function test_unitComposedPrice_success_OneHop() public {
        string[] memory symbols = new string[](2);
        symbols[0] = "ETH";
        symbols[1] = "weETH";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](2);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(chainlink),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        configs[1] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3),
            chainlinkFeed: address(chainlink),
            api3ToSymbol: "ETH",
            chainlinkToSymbol: "ETH",
            underlyingDecimals: 18
        });

        oracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
        roles.allow(address(this));

        api3.setPrice(105e8);
        api3.setUpdatedAt(block.timestamp);
        chainlink.setPrice(100e8);
        chainlink.setUpdatedAt(block.timestamp);

        api3.setPrice(3000e8);
        chainlink.setPrice(2700e8);

        // should revert because composed delta is too high
        vm.expectRevert();
        oracle.getPrice(address(token));
    }

    function test_unitComposedPrice_success_UsesParentUpdate() public {
        MockAdapter api3Eth = new MockAdapter();
        MockAdapter chainlinkEth = new MockAdapter();
        MockAdapter api3WeEth = new MockAdapter();
        MockAdapter chainlinkWeEth = new MockAdapter();

        api3Eth.setPrice(2000e8);
        chainlinkEth.setPrice(2000e8);
        api3WeEth.setPrice(2e8);
        chainlinkWeEth.setPrice(2e8);

        api3Eth.setUpdatedAt(block.timestamp - 50);
        api3WeEth.setUpdatedAt(block.timestamp - 10);
        chainlinkEth.setUpdatedAt(block.timestamp - 60);
        chainlinkWeEth.setUpdatedAt(block.timestamp - 20);

        string[] memory symbols = new string[](2);
        symbols[0] = "ETH";
        symbols[1] = "WEETH";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](2);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3Eth),
            chainlinkFeed: address(chainlinkEth),
            api3ToSymbol: "USD",
            chainlinkToSymbol: "USD",
            underlyingDecimals: 18
        });
        configs[1] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3WeEth),
            chainlinkFeed: address(chainlinkWeEth),
            api3ToSymbol: "ETH",
            chainlinkToSymbol: "ETH",
            underlyingDecimals: 18
        });

        oracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
        roles.allow(address(this));

        token.setSymbol("WEETH");
        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 4000e18);
    }

    ////////////////////////////////////////////////////////////
    //                  RevertsIfNegativePrice                  //
    ////////////////////////////////////////////////////////////

    function test_unitRevertsIfNegativePrice_revertsWith() public {
        api3.setPrice(-1);
        chainlink.setPrice(-1);

        vm.expectRevert();
        oracle.getPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //                 UsesSymbolSpecificDelta                  //
    ////////////////////////////////////////////////////////////

    function test_unitUsesSymbolSpecificDelta_success() public {
        api3.setPrice(100e8);
        chainlink.setPrice(120e8);
        api3.setUpdatedAt(block.timestamp);
        chainlink.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 120e18);

        oracle.setSymbolMaxPriceDelta(25000, "MOCK"); // 25%
        price = oracle.getPrice(address(token));
        assertEq(price, 100e18);
    }

    ////////////////////////////////////////////////////////////
    //                     SetMaxPriceDelta                     //
    ////////////////////////////////////////////////////////////

    function test_fuzzSetMaxPriceDelta_success(uint256 delta) public {
        vm.assume(delta <= oracle.PRICE_DELTA_EXP());
        oracle.setMaxPriceDelta(delta);
        assertEq(oracle.maxPriceDelta(), delta);
    }

    ////////////////////////////////////////////////////////////
    //                  SetSymbolMaxPriceDelta                  //
    ////////////////////////////////////////////////////////////

    function test_fuzzSetSymbolMaxPriceDelta_success(uint256 delta) public {
        vm.assume(delta <= oracle.PRICE_DELTA_EXP());
        oracle.setSymbolMaxPriceDelta(delta, "MOCK");
        assertEq(oracle.deltaPerSymbol("MOCK"), delta);
    }
}
