// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {ChainlinkOracle} from "src/oracles/ChainlinkOracle.sol";
import {IAggregatorV3} from "src/interfaces/external/chainlink/IAggregatorV3.sol";

contract MockAggregatorV3 is IAggregatorV3 {
    uint8 public decimalsOverride;
    int256 public answer;
    uint256 public updatedAt;

    constructor(uint8 _decimals, int256 _answer) {
        decimalsOverride = _decimals;
        answer = _answer;
        updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return decimalsOverride;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer_, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        roundId = 1;
        answer_ = answer;
        startedAt = 0;
        updatedAt_ = updatedAt;
        answeredInRound = 1;
    }

    function setAnswer(int256 _answer) external {
        answer = _answer;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }
}

contract MockSymbolToken {
    string public symbol;

    constructor(string memory _symbol) {
        symbol = _symbol;
    }
}

contract MockMToken {
    string public symbol;
    address public underlying;

    constructor(string memory _symbol, address _underlying) {
        symbol = _symbol;
        underlying = _underlying;
    }
}

contract ChainlinkOracleHarness is ChainlinkOracle {
    constructor(string[] memory symbols_, IAggregatorV3[] memory feeds_, uint256[] memory baseUnits_)
        ChainlinkOracle(symbols_, feeds_, baseUnits_)
    {}

    function exposed_getLatestPrice(string memory symbol) external view returns (uint256, uint256) {
        return _getLatestPrice(symbol);
    }
}

contract ChainlinkOracleTest is Test {
    function test_getPrice_scalesFeedDecimals() external {
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

    function test_getUnderlyingPrice_scalesBaseUnits() external {
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

    function test_RevertWhen_NoFeed() external {
        string[] memory symbols = new string[](0);
        IAggregatorV3[] memory feeds = new IAggregatorV3[](0);
        uint256[] memory baseUnits = new uint256[](0);

        ChainlinkOracleHarness oracle = new ChainlinkOracleHarness(symbols, feeds, baseUnits);

        vm.expectRevert(ChainlinkOracle.ChainlinkOracle_NoPriceFeed.selector);
        oracle.exposed_getLatestPrice("MISSING");
    }

    function test_RevertWhen_ZeroPrice() external {
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

    function testFuzz_getPrice_scales(uint8 feedDecimals, uint64 rawPrice) external {
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

    function testFuzz_getUnderlyingPrice_scales(uint8 feedDecimals, uint8 underlyingDecimals, uint64 rawPrice) external {
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
