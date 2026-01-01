// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {Roles} from "src/Roles.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";

contract MockV3Feed is IDefaultAdapter {
    uint8 public override decimals;
    int256 public price;
    uint256 public updatedAt;

    constructor(uint8 _decimals, int256 _price) {
        decimals = _decimals;
        price = _price;
        updatedAt = block.timestamp;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound)
    {
        roundId = 1;
        answer = price;
        startedAt = 0;
        updatedAt_ = updatedAt;
        answeredInRound = 1;
    }

    function latestAnswer() external view returns (int256) {
        return price;
    }

    function latestTimestamp() external view returns (uint256) {
        return updatedAt;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }
}

    contract MockV3Token {
        string public symbol;

        constructor(string memory _symbol) {
            symbol = _symbol;
        }
    }

    contract MockV3MToken {
        string public symbol;
        address public underlying;

        constructor(string memory _symbol, address _underlying) {
            symbol = _symbol;
            underlying = _underlying;
        }
    }

    contract MixedPriceOracleV3AdminTest is Test {
        Roles internal roles;

        function setUp() public {
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
                IDefaultAdapter.PriceConfig({
                defaultFeed: feed, toSymbol: "USD", underlyingDecimals: underlyingDecimals
            });

            return new MixedPriceOracleV3(symbols, configs, address(roles), 1 days);
        }

        function test_setStaleness_updatesMapping() external {
            MockV3Feed feed = new MockV3Feed(8, 1e8);
            MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);

            oracle.setStaleness("MOCK", 1234);
            assertEq(oracle.stalenessPerSymbol("MOCK"), 1234);
        }

        function test_setStaleness_revertsWhenUnauthorized() external {
            MockV3Feed feed = new MockV3Feed(8, 1e8);
            MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);

            vm.prank(address(0xBEEF));
            vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_Unauthorized.selector);
            oracle.setStaleness("MOCK", 1234);
        }

        function test_setConfig_revertsWhenZeroFeed() external {
            MockV3Feed feed = new MockV3Feed(8, 1e8);
            MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);

            IDefaultAdapter.PriceConfig memory config =
                IDefaultAdapter.PriceConfig({defaultFeed: address(0), toSymbol: "USD", underlyingDecimals: 18});

            vm.expectRevert(MixedPriceOracleV3.MixedPriceOracle_InvalidConfig.selector);
            oracle.setConfig("MOCK", config);
        }

        function test_setConfig_updatesMapping() external {
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

        function test_getPrice_returnsScaledPrice() external {
            MockV3Feed feed = new MockV3Feed(8, 2_500e8);
            MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);
            MockV3MToken token = new MockV3MToken("MOCK", address(0));

            uint256 price = oracle.getPrice(address(token));
            assertEq(price, 2_500e18);
        }

        function testFuzz_getPrice_scales(uint8 feedDecimals, uint64 rawPrice) external {
            vm.assume(feedDecimals <= 18);
            vm.assume(rawPrice > 0);

            MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
            MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", 18);
            MockV3MToken token = new MockV3MToken("MOCK", address(0));

            uint256 price = oracle.getPrice(address(token));
            uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
            assertEq(price, expected);
        }

        function testFuzz_getUnderlyingPrice_scales(uint8 feedDecimals, uint8 underlyingDecimals, uint64 rawPrice)
            external
        {
            vm.assume(feedDecimals <= 18);
            vm.assume(underlyingDecimals <= 18);
            vm.assume(rawPrice > 0);

            MockV3Feed feed = new MockV3Feed(feedDecimals, int256(uint256(rawPrice)));
            MixedPriceOracleV3 oracle = _deployOracle(address(feed), "MOCK", underlyingDecimals);
            MockV3Token underlying = new MockV3Token("MOCK");
            MockV3MToken token = new MockV3MToken("mMOCK", address(underlying));

            uint256 price = oracle.getUnderlyingPrice(address(token));
            uint256 expected = uint256(rawPrice) * 10 ** (18 - feedDecimals);
            expected = expected * 10 ** (18 - underlyingDecimals);
            assertEq(price, expected);
        }
    }
