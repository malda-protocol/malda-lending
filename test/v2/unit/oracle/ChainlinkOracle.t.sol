// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ChainlinkOracle} from "src/oracles/ChainlinkOracle.sol";
import {IAggregatorV3} from "src/interfaces/external/chainlink/IAggregatorV3.sol";

import {MockAggregatorV3, MockMToken, MockSymbolToken} from "test/v2/mocks/oracles/ChainlinkOracleMocks.t.sol";
import {ChainlinkOracleHarness} from "test/v2/unit/oracle/harness/ChainlinkOracleHarness.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract ChainlinkOracleTest is BaseTest {
    ////////////////////////////////////////////////////////////
    //                         getPrice                       //
    ////////////////////////////////////////////////////////////

    function test_unit_getPrice_revertsWith_ChainlinkOracle_ZeroPrice() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockAggregatorV3 feed = new MockAggregatorV3(8, 0);
        ChainlinkOracle oracle = _deployOracle("MOCK", feed, 1e18);
        MockMToken token = new MockMToken("MOCK", address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ChainlinkOracle.ChainlinkOracle_ZeroPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_unit_getPrice_revertsWith_ChainlinkOracle_NoPriceFeed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string[] memory symbols = new string[](0);
        IAggregatorV3[] memory feeds = new IAggregatorV3[](0);
        uint256[] memory baseUnits = new uint256[](0);
        ChainlinkOracle oracle = new ChainlinkOracle(symbols, feeds, baseUnits);
        MockMToken token = new MockMToken("MISSING", address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getPrice(address(token));
    }

    function test_fuzz_getPrice_success_scalesFeedDecimals(uint8 feedDecimals, uint64 rawPrice) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        rawPrice = uint64(bound(rawPrice, 1, type(uint64).max));

        MockAggregatorV3 feed = new MockAggregatorV3(feedDecimals, int256(uint256(rawPrice)));
        ChainlinkOracle oracle = _deployOracle("MOCK", feed, 1e18);
        MockMToken token = new MockMToken("MOCK", address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        assertEq(price, expected, "expected price to equal expected");
    }

    function test_fuzz_getPrice_success_scales_to18Decimals(uint8 feedDecimals, uint64 rawPrice) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        rawPrice = uint64(bound(rawPrice, 1, type(uint64).max));

        MockAggregatorV3 feed = new MockAggregatorV3(feedDecimals, int256(uint256(rawPrice)));
        ChainlinkOracle oracle = _deployOracle("MOCK", feed, 1e18);
        MockMToken token = new MockMToken("MOCK", address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
        assertEq(price, expected, "expected price to equal expected");
    }

    ////////////////////////////////////////////////////////////
    //                   getUnderlyingPrice                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getUnderlyingPrice_success_scalesBaseUnits(
        uint8 feedDecimals,
        uint8 underlyingDecimals,
        uint64 rawPrice
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        feedDecimals = uint8(bound(feedDecimals, 4, 18));
        underlyingDecimals = uint8(bound(underlyingDecimals, 4, 18));
        rawPrice = uint64(bound(rawPrice, 1, type(uint64).max));

        MockAggregatorV3 feed = new MockAggregatorV3(feedDecimals, int256(uint256(rawPrice)));
        MockSymbolToken underlying = new MockSymbolToken("MOCK");
        MockMToken token = new MockMToken("mMOCK", address(underlying));
        ChainlinkOracle oracle = _deployOracle("MOCK", feed, 10 ** underlyingDecimals);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 price = oracle.getUnderlyingPrice(address(token));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 expected = (uint256(rawPrice) * (10 ** (36 - feedDecimals))) / (10 ** underlyingDecimals);
        assertEq(price, expected, "expected price to equal expected");
    }

    function test_unit_getUnderlyingPrice_revertsWith_ChainlinkOracle_NoPriceFeed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string[] memory symbols = new string[](0);
        IAggregatorV3[] memory feeds = new IAggregatorV3[](0);
        uint256[] memory baseUnits = new uint256[](0);
        ChainlinkOracle oracle = new ChainlinkOracle(symbols, feeds, baseUnits);

        MockSymbolToken underlying = new MockSymbolToken("MISSING");
        MockMToken token = new MockMToken("mMISSING", address(underlying));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getUnderlyingPrice(address(token));
    }

    function test_unit_getUnderlyingPrice_revertsWith_ChainlinkOracle_ZeroPrice() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockAggregatorV3 feed = new MockAggregatorV3(8, 0);
        MockSymbolToken underlying = new MockSymbolToken("MOCK");
        MockMToken token = new MockMToken("mMOCK", address(underlying));
        ChainlinkOracle oracle = _deployOracle("MOCK", feed, 1e8);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ChainlinkOracle.ChainlinkOracle_ZeroPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.getUnderlyingPrice(address(token));
    }

    ////////////////////////////////////////////////////////////
    //                   exposed_getLatestPrice               //
    ////////////////////////////////////////////////////////////

    function test_unit_exposed_getLatestPrice_revertsWith_ChainlinkOracle_NoPriceFeed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        string[] memory symbols = new string[](0);
        IAggregatorV3[] memory feeds = new IAggregatorV3[](0);
        uint256[] memory baseUnits = new uint256[](0);

        ChainlinkOracleHarness oracle = new ChainlinkOracleHarness(symbols, feeds, baseUnits);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ChainlinkOracle.ChainlinkOracle_NoPriceFeed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        oracle.exposed_getLatestPrice("MISSING");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _deployOracle(string memory symbol, IAggregatorV3 feed, uint256 baseUnit)
        internal
        returns (ChainlinkOracle)
    {
        string[] memory symbols = new string[](1);
        symbols[0] = symbol;

        IAggregatorV3[] memory feeds = new IAggregatorV3[](1);
        feeds[0] = feed;

        uint256[] memory baseUnits = new uint256[](1);
        baseUnits[0] = baseUnit;

        return new ChainlinkOracle(symbols, feeds, baseUnits);
    }
}
