// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";

contract MockAdapter {
    uint8 public decimals = 8;
    int256 public price = 1e8;
    uint256 public updatedAt = block.timestamp;

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, price, 0, updatedAt, 0);
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _time) external {
        updatedAt = _time;
    }
}

contract MockRoles {
    mapping(address account => bool allowed) public allowed;

    function GUARDIAN_ORACLE() external pure returns (bytes32) {
        return keccak256("GUARDIAN_ORACLE");
    }

    function isAllowedFor(address user, bytes32) external view returns (bool) {
        return allowed[user];
    }

    function allow(address user) external {
        allowed[user] = true;
    }
}

contract MockToken {
    string public symbol_ = "MOCK";
    address public underlying_ = address(this);

    function symbol() external view returns (string memory) {
        return symbol_;
    }

    function underlying() external view returns (address) {
        return underlying_;
    }

    function setSymbol(string calldata _symbol) external {
        symbol_ = _symbol;
    }

    function setUnderlying(address _underlying) external {
        underlying_ = _underlying;
    }
}

contract MixedPriceOracleV4Test is Test {
    MixedPriceOracleV4 internal oracle;
    MockAdapter internal api3;
    MockAdapter internal eOracle;
    MockRoles internal roles;
    MockToken internal token;

    function setUp() public {
        api3 = new MockAdapter();
        eOracle = new MockAdapter();
        roles = new MockRoles();
        token = new MockToken();

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3), eOracleFeed: address(eOracle), toSymbol: "USD", underlyingDecimals: 18
        });

        oracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
        roles.allow(address(this));

        vm.warp(100 days);
    }

    function testSetStaleness() public {
        oracle.setStaleness("MOCK", 1234);
        assertEq(oracle.stalenessPerSymbol("MOCK"), 1234);
    }

    function testSetStaleness_revertWhenUnauthorized() public {
        MockRoles newRoles = new MockRoles();

        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3), eOracleFeed: address(eOracle), toSymbol: "USD", underlyingDecimals: 18
        });

        MixedPriceOracleV4 newOracle = new MixedPriceOracleV4(symbols, configs, address(newRoles), 1 days);

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_Unauthorized.selector);
        newOracle.setStaleness("MOCK", 1234);
    }

    function test_constructor_revertWhenRolesZero() public {
        string[] memory symbols = new string[](1);
        symbols[0] = "MOCK";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](1);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3), eOracleFeed: address(eOracle), toSymbol: "USD", underlyingDecimals: 18
        });

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_AddressNotValid.selector);
        new MixedPriceOracleV4(symbols, configs, address(0), 1 days);
    }

    function testSetMaxPriceDelta() public {
        oracle.setMaxPriceDelta(500);
        assertEq(oracle.maxPriceDelta(), 500);
    }

    function testSetMaxPriceDelta_revertWhenTooHigh() public {
        uint256 delta = oracle.PRICE_DELTA_EXP() + 1;
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);
        oracle.setMaxPriceDelta(delta);
    }

    function testSetSymbolMaxPriceDelta() public {
        oracle.setSymbolMaxPriceDelta(400, "MOCK");
        assertEq(oracle.deltaPerSymbol("MOCK"), 400);
    }

    function testSetSymbolMaxPriceDelta_revertWhenTooHigh() public {
        uint256 delta = oracle.PRICE_DELTA_EXP() + 1;
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_DeltaTooHigh.selector);
        oracle.setSymbolMaxPriceDelta(delta, "MOCK");
    }

    function testSetConfig() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3), eOracleFeed: address(eOracle), toSymbol: "USD", underlyingDecimals: 18
        });
        oracle.setConfig("MOCK", cfg);
    }

    function testSetConfig_revertWhenApi3FeedZero() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(0), eOracleFeed: address(eOracle), toSymbol: "USD", underlyingDecimals: 18
        });

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_InvalidConfig.selector);
        oracle.setConfig("MOCK", cfg);
    }

    function testSetConfig_revertWhenEOracleFeedZero() public {
        MixedPriceOracleV4.PriceConfig memory cfg = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3), eOracleFeed: address(0), toSymbol: "USD", underlyingDecimals: 18
        });

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_InvalidConfig.selector);
        oracle.setConfig("MOCK", cfg);
    }

    function testGetPrice() public {
        eOracle.setUpdatedAt(block.timestamp - 10);
        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 1e18); // since price is 1e8 and decimals = 8
    }

    function testGetPrice_usesApi3WhenFresh() public {
        api3.setPrice(100e8);
        eOracle.setPrice(101e8);
        api3.setUpdatedAt(block.timestamp);
        eOracle.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 100e18);
    }

    function testGetPrice_revertWhenMissingFeed() public {
        token.setSymbol("MISSING");
        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_MissingFeed.selector);
        oracle.getPrice(address(token));
    }

    function testGetUnderlyingPrice() public {
        eOracle.setUpdatedAt(block.timestamp - 10);
        uint256 price = oracle.getUnderlyingPrice(address(token));
        assertEq(price, 1e18); // same as getPrice because underlyingDecimals = 18
    }

    function testUseEOracleOnApi3Stale() public {
        api3.setUpdatedAt(block.timestamp - 2 days);
        eOracle.setPrice(2e8);
        eOracle.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 2e18);
    }

    function testRevertIfBothStale() public {
        api3.setUpdatedAt(block.timestamp - 2 days);
        eOracle.setUpdatedAt(block.timestamp - 2 days);

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_eOracleStalePrice.selector);
        oracle.getPrice(address(token));
    }

    function testFallbackToEOracleOnDeltaTooHigh() public {
        // api3 = 1e8, eOracle = 3e8 -> 200% delta
        eOracle.setPrice(3e8);
        eOracle.setUpdatedAt(block.timestamp);

        oracle.setSymbolMaxPriceDelta(1500, "MOCK"); // 1.5% allowed

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 3e18);
    }

    function test_FailsIfDeltaTooHighAndEOracleStale() public {
        eOracle.setPrice(3e8);
        eOracle.setUpdatedAt(block.timestamp - 2 days);
        oracle.setSymbolMaxPriceDelta(1500, "MOCK");

        vm.expectRevert(MixedPriceOracleV4.MixedPriceOracle_eOracleStalePrice.selector);
        oracle.getPrice(address(token));
    }

    function test_ComposedPrice_OneHop() public {
        string[] memory symbols = new string[](2);
        symbols[0] = "ETH";
        symbols[1] = "weETH";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](2);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3), eOracleFeed: address(eOracle), toSymbol: "USD", underlyingDecimals: 18
        });
        configs[1] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3), eOracleFeed: address(eOracle), toSymbol: "ETH", underlyingDecimals: 18
        });

        oracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
        roles.allow(address(this));

        api3.setPrice(105e8);
        api3.setUpdatedAt(block.timestamp);
        eOracle.setPrice(100e8);
        eOracle.setUpdatedAt(block.timestamp);

        api3.setPrice(3000e8);
        eOracle.setPrice(2700e8);

        // should revert because composed delta is too high
        vm.expectRevert();
        oracle.getPrice(address(token));
    }

    function test_ComposedPrice_UsesParentUpdate() public {
        MockAdapter api3Eth = new MockAdapter();
        MockAdapter eOracleEth = new MockAdapter();
        MockAdapter api3WeEth = new MockAdapter();
        MockAdapter eOracleWeEth = new MockAdapter();

        api3Eth.setPrice(2000e8);
        eOracleEth.setPrice(2000e8);
        api3WeEth.setPrice(2e8);
        eOracleWeEth.setPrice(2e8);

        api3Eth.setUpdatedAt(block.timestamp - 50);
        api3WeEth.setUpdatedAt(block.timestamp - 10);
        eOracleEth.setUpdatedAt(block.timestamp - 60);
        eOracleWeEth.setUpdatedAt(block.timestamp - 20);

        string[] memory symbols = new string[](2);
        symbols[0] = "ETH";
        symbols[1] = "WEETH";

        MixedPriceOracleV4.PriceConfig[] memory configs = new MixedPriceOracleV4.PriceConfig[](2);
        configs[0] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3Eth), eOracleFeed: address(eOracleEth), toSymbol: "USD", underlyingDecimals: 18
        });
        configs[1] = MixedPriceOracleV4.PriceConfig({
            api3Feed: address(api3WeEth), eOracleFeed: address(eOracleWeEth), toSymbol: "ETH", underlyingDecimals: 18
        });

        oracle = new MixedPriceOracleV4(symbols, configs, address(roles), 1 days);
        roles.allow(address(this));

        token.setSymbol("WEETH");
        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 4000e18);
    }

    function test_RevertsIfNegativePrice() public {
        api3.setPrice(-1);
        eOracle.setPrice(-1);

        vm.expectRevert();
        oracle.getPrice(address(token));
    }

    function test_UsesSymbolSpecificDelta() public {
        api3.setPrice(100e8);
        eOracle.setPrice(120e8);
        api3.setUpdatedAt(block.timestamp);
        eOracle.setUpdatedAt(block.timestamp);

        uint256 price = oracle.getPrice(address(token));
        assertEq(price, 120e18);

        oracle.setSymbolMaxPriceDelta(25000, "MOCK"); // 25%
        price = oracle.getPrice(address(token));
        assertEq(price, 100e18);
    }

    function testFuzz_setMaxPriceDelta(uint256 delta) public {
        vm.assume(delta <= oracle.PRICE_DELTA_EXP());
        oracle.setMaxPriceDelta(delta);
        assertEq(oracle.maxPriceDelta(), delta);
    }

    function testFuzz_setSymbolMaxPriceDelta(uint256 delta) public {
        vm.assume(delta <= oracle.PRICE_DELTA_EXP());
        oracle.setSymbolMaxPriceDelta(delta, "MOCK");
        assertEq(oracle.deltaPerSymbol("MOCK"), delta);
    }
}
