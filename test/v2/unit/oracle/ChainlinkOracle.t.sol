// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {ChainlinkOracle} from "src/oracles/ChainlinkOracle.sol";
import {IAggregatorV3} from "src/interfaces/external/chainlink/IAggregatorV3.sol";
import {MockAggregatorV3, MockMToken, MockSymbolToken} from "test/v2/mocks/oracles/ChainlinkOracleMocks.t.sol";

contract ChainlinkOracleHarness is ChainlinkOracle {
    constructor(string[] memory symbols_, IAggregatorV3[] memory feeds_, uint256[] memory baseUnits_)
        ChainlinkOracle(symbols_, feeds_, baseUnits_)
    {}

    function exposed_getLatestPrice(string calldata symbol) external view returns (uint256, uint256) {
        return _getLatestPrice(symbol);
    }
}

contract ChainlinkOracleTest is BaseTest {
    ////////////////////////////////////////////////////////////
    //                         GetPrice                         //
    ////////////////////////////////////////////////////////////

    function test_unitGetPrice_success_scalesFeedDecimals() external {
        MockAggregatorV3 feed = new MockAggregatorV3(8, 2_000e8);
        MockMToken token = new MockMToken("MOCK", address(0));

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";
        IAggregatorV3[] memory feeds = new IAggregatorV3[](1);
        feeds[0] = feed;
        uint256[] memory baseUnits = new uint256[](1);
        baseUnits[0] = 1e18;

        ChainlinkOracle oracle = new ChainlinkOracle(symbols, feeds, baseUnits);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 2_000e18);
    }

    ////////////////////////////////////////////////////////////
    //                    GetUnderlyingPrice                    //
    ////////////////////////////////////////////////////////////

    function test_unitGetUnderlyingPrice_success_scalesBaseUnits() external {
        MockAggregatorV3 feed = new MockAggregatorV3(8, 3_500e8);
        MockSymbolToken underlying = new MockSymbolToken("MOCK");
        MockMToken token = new MockMToken("mMOCK", address(underlying));

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";
        IAggregatorV3[] memory feeds = new IAggregatorV3[](1);
        feeds[0] = feed;
        uint256[] memory baseUnits = new uint256[](1);
        baseUnits[0] = 1e6;

        ChainlinkOracle oracle = new ChainlinkOracle(symbols, feeds, baseUnits);

        uint256 price = oracle.getUnderlyingPrice(address(token));
        assertEq(price, (3_500e8 * 10 ** 28) / 1e6);
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_NoFeed() external {
        string[] memory symbols = new string[](0);
        IAggregatorV3[] memory feeds = new IAggregatorV3[](0);
        uint256[] memory baseUnits = new uint256[](0);

        ChainlinkOracleHarness oracle = new ChainlinkOracleHarness(symbols, feeds, baseUnits);

        vm.expectRevert(ChainlinkOracle.ChainlinkOracle_NoPriceFeed.selector);
        oracle.exposed_getLatestPrice("MISSING");
    }

    function test_unitRevertWhen_revertsWith_ZeroPrice() external {
        MockAggregatorV3 feed = new MockAggregatorV3(8, 0);
        MockMToken token = new MockMToken("MOCK", address(0));

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";
        IAggregatorV3[] memory feeds = new IAggregatorV3[](1);
        feeds[0] = feed;
        uint256[] memory baseUnits = new uint256[](1);
        baseUnits[0] = 1e18;

        ChainlinkOracle oracle = new ChainlinkOracle(symbols, feeds, baseUnits);

        vm.expectRevert(ChainlinkOracle.ChainlinkOracle_ZeroPrice.selector);
        oracle.getPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //                         GetPrice                         //
    ////////////////////////////////////////////////////////////

    function test_fuzzGetPrice_success_scales(uint8 feedDecimals, uint64 rawPrice) external {
        vm.assume(feedDecimals <= 18);
        vm.assume(rawPrice > 0);

        MockAggregatorV3 feed = new MockAggregatorV3(feedDecimals, int256(uint256(rawPrice)));
        MockMToken token = new MockMToken("MOCK", address(0));

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";
        IAggregatorV3[] memory feeds = new IAggregatorV3[](1);
        feeds[0] = feed;
        uint256[] memory baseUnits = new uint256[](1);
        baseUnits[0] = 1e18;

        ChainlinkOracle oracle = new ChainlinkOracle(symbols, feeds, baseUnits);

        uint256 price = oracle.getPrice(address(token));
        uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        assertEq(price, expected);
    }

    ////////////////////////////////////////////////////////////
    //                    GetUnderlyingPrice                    //
    ////////////////////////////////////////////////////////////

    function test_fuzzGetUnderlyingPrice_success_scales(uint8 feedDecimals, uint8 underlyingDecimals, uint64 rawPrice)
        external
    {
        vm.assume(feedDecimals <= 18);
        vm.assume(underlyingDecimals <= 18);
        vm.assume(rawPrice > 0);

        MockAggregatorV3 feed = new MockAggregatorV3(feedDecimals, int256(uint256(rawPrice)));
        MockSymbolToken underlying = new MockSymbolToken("MOCK");
        MockMToken token = new MockMToken("mMOCK", address(underlying));

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";
        IAggregatorV3[] memory feeds = new IAggregatorV3[](1);
        feeds[0] = feed;
        uint256[] memory baseUnits = new uint256[](1);
        baseUnits[0] = 10 ** underlyingDecimals;

        ChainlinkOracle oracle = new ChainlinkOracle(symbols, feeds, baseUnits);

        uint256 price = oracle.getUnderlyingPrice(address(token));
        uint256 expected = (uint256(rawPrice) * (10 ** (36 - feedDecimals))) / baseUnits[0];
        assertEq(price, expected);
    }
}
