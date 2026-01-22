// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IRoles} from "src/interfaces/IRoles.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IOracleOperator} from "src/interfaces/IOracleOperator.sol";
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";

/// @title MixedPriceOracleV4
/// @author Merge Layers Inc.
/// @notice Mixed price oracle using dual feeds and staleness checks
contract MixedPriceOracleV4 is IOracleOperator {
    // ----------- STORAGE ------------
    struct PriceConfig {
        address api3Feed;
        address chainlinkFeed;
        string toSymbol;
        uint256 underlyingDecimals;
    }

    // ----------- CONSTANTS ------------
    /// @notice Price delta exponent (basis points denominator)
    uint256 public constant PRICE_DELTA_EXP = 1e5;

    // ----------- IMMUTABLES ------------
    /// @notice Default staleness period applied to feeds
    uint256 public immutable STALENESS_PERIOD;

    /// @notice Roles contract reference
    IRoles public immutable ROLES;

    // ----------- STORAGE ------------
    /// @notice Mapping of symbols to price configs
    mapping(string symbol => PriceConfig config) public configs;

    /// @notice Mapping of symbols to custom staleness
    mapping(string symbol => uint256 staleness) public stalenessPerSymbol;

    /// @notice Mapping of symbols to custom price deltas
    mapping(string symbol => uint256 delta) public deltaPerSymbol;

    /// @notice Maximum allowed delta in basis points for price comparison
    uint256 public maxPriceDelta = 1.5e3; // 1.5%

    // ----------- EVENTS ------------
    /// @notice Emitted when a config is set for a symbol
    /// @param symbol Symbol being configured
    /// @param config Price config stored
    event ConfigSet(string symbol, PriceConfig config);

    /// @notice Emitted when staleness is updated for a symbol
    /// @param symbol Symbol being updated
    /// @param val New staleness period
    event StalenessUpdated(string symbol, uint256 val);

    /// @notice Emitted when global price delta is updated
    /// @param oldVal Previous delta value
    /// @param newVal New delta value
    event PriceDeltaUpdated(uint256 oldVal, uint256 newVal);

    /// @notice Emitted when symbol price delta is updated
    /// @param oldVal Previous delta
    /// @param newVal New delta
    /// @param symbol Symbol affected
    event PriceSymbolDeltaUpdated(uint256 oldVal, uint256 newVal, string symbol);

    // ----------- ERRORS ------------
    /// @notice Error thrown when caller is unauthorized
    error MixedPriceOracle_Unauthorized();

    /// @notice Error thrown when API3 feed price is stale
    error MixedPriceOracle_ApiV3StalePrice();

    /// @notice Error thrown when secondary feed price is stale
    error MixedPriceOracle_ChainlinkStalePrice();

    /// @notice Error thrown when price returned is invalid
    error MixedPriceOracle_InvalidPrice();

    /// @notice Error thrown when provided config is invalid
    error MixedPriceOracle_InvalidConfig();

    /// @notice Error thrown when delta exceeds allowed max
    error MixedPriceOracle_DeltaTooHigh();

    /// @notice Error thrown when required feed is missing
    error MixedPriceOracle_MissingFeed();

    /// @notice Error thrown when roles contract address is invalid
    error MixedPriceOracle_AddressNotValid();

    // ----------- MODIFIERS ------------
    /// @notice Modifier to check if the caller has specific role
    /// @param role Role identifier to check
    modifier onlyRole(bytes32 role) {
        // Requirements: the caller has the specified role
        _onlyRole(role);
        _;
    }

    /// @notice Initializes the oracle with configs, roles, and staleness
    /// @param symbols_ Symbols being configured
    /// @param configs_ Price configs for symbols
    /// @param roles_ Roles contract address
    /// @param stalenessPeriod_ Default staleness period
    constructor(string[] memory symbols_, PriceConfig[] memory configs_, address roles_, uint256 stalenessPeriod_) {
        // Requirements: the roles contract address is not zero
        require(roles_ != address(0), MixedPriceOracle_AddressNotValid());

        // Requirements: the symbols and configs lengths match
        CommonLib.checkLengthMatch(symbols_.length, configs_.length);

        // Effects: set the roles
        ROLES = IRoles(roles_);

        // Effects: set the staleness period
        STALENESS_PERIOD = stalenessPeriod_;

        for (uint256 i = 0; i < symbols_.length; i++) {
            // Effects: set the price config
            configs[symbols_[i]] = configs_[i];
        }
    }

    // ----------- ADMIN ------------
    /// @notice Sets a custom staleness for a symbol
    /// @param symbol Symbol to update
    /// @param val New staleness value
    function setStaleness(string calldata symbol, uint256 val) external onlyRole(ROLES.GUARDIAN_ORACLE()) {
        // Effects: set the staleness
        stalenessPerSymbol[symbol] = val;

        // Events: emit the staleness updated event
        emit StalenessUpdated(symbol, val);
    }

    /// @notice Sets price configuration for a symbol
    /// @param symbol Symbol to configure
    /// @param config Price configuration
    function setConfig(string calldata symbol, PriceConfig calldata config) external onlyRole(ROLES.GUARDIAN_ORACLE()) {
        // Requirements: the primary feed is set (secondary is optional e.g. for rsETH/ETH)
        require(config.api3Feed != address(0), MixedPriceOracle_InvalidConfig());

        // Effects: set the price config
        configs[symbol] = config;

        // Events: emit the config set event
        emit ConfigSet(symbol, config);
    }

    /// @notice Sets maximum allowed price delta
    /// @param _delta New max delta in basis points
    function setMaxPriceDelta(uint256 _delta) external onlyRole(ROLES.GUARDIAN_ORACLE()) {
        // Requirements: the max price delta is not greater than the price delta exponent
        require(_delta <= PRICE_DELTA_EXP, MixedPriceOracle_DeltaTooHigh());

        // Events: emit the price delta updated event
        emit PriceDeltaUpdated(maxPriceDelta, _delta);

        // Effects: set the max price delta
        maxPriceDelta = _delta;
    }

    /// @notice Sets maximum price delta for a specific symbol
    /// @param _delta New delta in basis points
    /// @param _symbol Symbol to update
    function setSymbolMaxPriceDelta(uint256 _delta, string calldata _symbol)
        external
        onlyRole(ROLES.GUARDIAN_ORACLE())
    {
        // Requirements: the symbol max price delta is not greater than the price delta exponent
        require(_delta <= PRICE_DELTA_EXP, MixedPriceOracle_DeltaTooHigh());

        // Events: emit the price symbol delta updated event
        emit PriceSymbolDeltaUpdated(deltaPerSymbol[_symbol], _delta, _symbol);

        // Effects: set the symbol max price delta
        deltaPerSymbol[_symbol] = _delta;
    }

    // ----------- PUBLIC API ------------
    /// @notice Returns price for an mToken
    /// @param mToken Address of the mToken
    /// @return Price denominated in USD with 18 decimals
    function getPrice(address mToken) external view returns (uint256) {
        string memory symbol = ImTokenMinimal(mToken).symbol();
        return _getPriceUSD(symbol);
    }

    /// @notice Returns underlying price for an mToken
    /// @param mToken Address of the mToken
    /// @return Price denominated in USD with 18 decimals adjusted for underlying decimals
    function getUnderlyingPrice(address mToken) external view override returns (uint256) {
        string memory symbol = ImTokenMinimal(ImTokenMinimal(mToken).underlying()).symbol();
        PriceConfig memory config = configs[symbol];
        uint256 priceUsd = _getPriceUSD(symbol);
        return priceUsd * 10 ** (18 - config.underlyingDecimals);
    }

    // ----------- CORE LOGIC ------------
    /// @notice Ensures caller has specific role
    /// @param role Role identifier to check
    function _onlyRole(bytes32 role) internal view {
        // Requirements: the caller has the specified role
        require(ROLES.isAllowedFor(msg.sender, role), MixedPriceOracle_Unauthorized());
    }

    /// @notice Returns USD price for a symbol using dual feeds
    /// @param symbol Token symbol
    /// @return USD price with 18 decimals
    function _getPriceUSD(string memory symbol) internal view returns (uint256) {
        PriceConfig memory config = configs[symbol];
        // Requirements: the primary feed is set
        require(config.api3Feed != address(0), MixedPriceOracle_MissingFeed());

        // Interactions: compute USD price from primary feed
        (uint256 api3Usd, uint256 api3LastUpdate) = _getApi3Price(symbol);

        uint256 deltaSymbol = deltaPerSymbol[symbol];
        if (deltaSymbol == 0) deltaSymbol = maxPriceDelta;

        // Check staleness
        uint256 _staleness = _getStaleness(symbol);
        bool api3Fresh = _isFresh(api3LastUpdate, _staleness);

        // If no secondary feed is configured, rely solely on API3
        if (config.chainlinkFeed == address(0)) {
            require(api3Fresh, MixedPriceOracle_ApiV3StalePrice());
            return api3Usd;
        }

        // Interactions: compute USD price from secondary feed
        (uint256 chainlinkUsd, uint256 chainlinkLastUpdate) = _getChainlinkPrice(symbol);

        // Calculate the price delta
        uint256 delta = _absDiff(int256(api3Usd), int256(chainlinkUsd));
        uint256 deltaBps = (delta * PRICE_DELTA_EXP) / chainlinkUsd;

        // If API3 is stale or delta is greater than the symbol max price delta, return the secondary price
        if (!api3Fresh || deltaBps > deltaSymbol) {
            // Requirements: the secondary feed is not stale
            require(_isFresh(chainlinkLastUpdate, _staleness), MixedPriceOracle_ChainlinkStalePrice());
            return chainlinkUsd;
        }

        // Requirements: the API3 feed is not stale
        require(_isFresh(api3LastUpdate, _staleness), MixedPriceOracle_ApiV3StalePrice());
        return api3Usd;
    }

    /// @notice Retrieves price and last update from API3 feed
    /// @param symbol Token symbol
    /// @return price Price scaled to 18 decimals
    /// @return lastUpdate Timestamp of last update
    function _getApi3Price(string memory symbol) internal view returns (uint256 price, uint256 lastUpdate) {
        PriceConfig memory config = configs[symbol];
        (, int256 api3Price,, uint256 api3UpdatedAt,) = IDefaultAdapter(config.api3Feed).latestRoundData();

        uint256 decimalsApi3Feed = IDefaultAdapter(config.api3Feed).decimals();
        price = uint256(api3Price) * 10 ** (18 - decimalsApi3Feed);
        lastUpdate = api3UpdatedAt;

        if (keccak256(abi.encodePacked(config.toSymbol)) != keccak256(abi.encodePacked("USD"))) {
            (uint256 api3CrtPrice, uint256 parentUpdate) = _getApi3Price(config.toSymbol);
            price = (price * api3CrtPrice) / 1e18;

            if (parentUpdate < lastUpdate) {
                lastUpdate = parentUpdate;
            }
        }
    }

    /// @notice Retrieves price and last update from secondary feed
    /// @param symbol Token symbol
    /// @return price Price scaled to 18 decimals
    /// @return lastUpdate Timestamp of last update
    function _getChainlinkPrice(string memory symbol) internal view returns (uint256 price, uint256 lastUpdate) {
        PriceConfig memory config = configs[symbol];
        (, int256 chainlinkPrice,, uint256 chainlinkUpdatedAt,) =
            IDefaultAdapter(config.chainlinkFeed).latestRoundData();

        uint256 decimalsChainlinkFeed = IDefaultAdapter(config.chainlinkFeed).decimals();
        price = uint256(chainlinkPrice) * 10 ** (18 - decimalsChainlinkFeed);
        lastUpdate = chainlinkUpdatedAt;

        if (keccak256(abi.encodePacked(config.toSymbol)) != keccak256(abi.encodePacked("USD"))) {
            (uint256 chainlinkCrtPrice, uint256 parentUpdate) = _getChainlinkPrice(config.toSymbol);
            price = (price * chainlinkCrtPrice) / 1e18;

            if (parentUpdate < lastUpdate) {
                lastUpdate = parentUpdate;
            }
        }
    }

    // Safe freshness check helper
    /// @notice Checks if price data is fresh
    /// @param updatedAt Timestamp of last update
    /// @param staleness Allowed staleness threshold
    /// @return True if data is within staleness window
    function _isFresh(uint256 updatedAt, uint256 staleness) internal view returns (bool) {
        uint256 timeDiff = updatedAt > block.timestamp ? updatedAt - block.timestamp : block.timestamp - updatedAt;
        return timeDiff <= staleness;
    }

    // ----------- HELPERS ------------
    /// @notice Returns staleness for a symbol or default
    /// @param symbol Token symbol
    /// @return Staleness period in seconds
    function _getStaleness(string memory symbol) internal view returns (uint256) {
        uint256 _registered = stalenessPerSymbol[symbol];
        return _registered > 0 ? _registered : STALENESS_PERIOD;
    }

    /// @notice Absolute difference between two int256 values
    /// @param a First value
    /// @param b Second value
    /// @return Absolute difference as uint256
    function _absDiff(int256 a, int256 b) internal pure returns (uint256) {
        return uint256(a >= b ? a - b : b - a);
    }
}
