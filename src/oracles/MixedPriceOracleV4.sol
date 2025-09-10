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

contract MixedPriceOracleV4 is IOracleOperator {
    uint256 public immutable STALENESS_PERIOD;

    // ----------- STORAGE ------------
    struct PriceConfig {
        address api3Feed;
        address eOracleFeed;
        string toSymbol;
        uint256 underlyingDecimals;
    }

    mapping(string => PriceConfig) public configs;
    mapping(string => uint256) public stalenessPerSymbol;
    mapping(string => uint256) public deltaPerSymbol;

    uint256 public maxPriceDelta = 1.5e3; // 1.5%
    uint256 public constant PRICE_DELTA_EXP = 1e5;
    IRoles public immutable roles;

    // ----------- ERRORS ------------
    error MixedPriceOracle_Unauthorized();
    error MixedPriceOracle_ApiV3StalePrice();
    error MixedPriceOracle_eOracleStalePrice();
    error MixedPriceOracle_InvalidPrice();
    error MixedPriceOracle_InvalidConfig();
    error MixedPriceOracle_DeltaTooHigh();
    error MixedPriceOracle_MissingFeed();

    // ----------- EVENTS ------------
    event ConfigSet(string symbol, PriceConfig config);
    event StalenessUpdated(string symbol, uint256 val);
    event PriceDeltaUpdated(uint256 oldVal, uint256 newVal);
    event PriceSymbolDeltaUpdated(uint256 oldVal, uint256 newVal, string symbol);

    constructor(
        string[] memory symbols_,
        PriceConfig[] memory configs_,
        address roles_,
        uint256 stalenessPeriod_
    ) {
        roles = IRoles(roles_);
        for (uint256 i = 0; i < symbols_.length; i++) {
            configs[symbols_[i]] = configs_[i];
        }
        STALENESS_PERIOD = stalenessPeriod_;
    }

    // ----------- ADMIN ------------
    function setStaleness(string memory symbol, uint256 val) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_ORACLE())) {
            revert MixedPriceOracle_Unauthorized();
        }
        stalenessPerSymbol[symbol] = val;
        emit StalenessUpdated(symbol, val);
    }

    function setConfig(string memory symbol, PriceConfig memory config) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_ORACLE())) {
            revert MixedPriceOracle_Unauthorized();
        }
        if (config.api3Feed == address(0) || config.eOracleFeed == address(0)) {
            revert MixedPriceOracle_InvalidConfig();
        }

        configs[symbol] = config;
        emit ConfigSet(symbol, config);
    }

    function setMaxPriceDelta(uint256 _delta) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_ORACLE())) {
            revert MixedPriceOracle_Unauthorized();
        }
        if (_delta > PRICE_DELTA_EXP) revert MixedPriceOracle_DeltaTooHigh();

        emit PriceDeltaUpdated(maxPriceDelta, _delta);
        maxPriceDelta = _delta;
    }

    function setSymbolMaxPriceDelta(uint256 _delta, string calldata _symbol) external {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_ORACLE())) {
            revert MixedPriceOracle_Unauthorized();
        }
        if (_delta > PRICE_DELTA_EXP) revert MixedPriceOracle_DeltaTooHigh();

        emit PriceSymbolDeltaUpdated(deltaPerSymbol[_symbol], _delta, _symbol);
        deltaPerSymbol[_symbol] = _delta;
    }

    // ----------- PUBLIC API ------------
    function getPrice(address mToken) public view returns (uint256) {
        string memory symbol = ImTokenMinimal(mToken).symbol();
        return _getPriceUSD(symbol);
    }

    function getUnderlyingPrice(address mToken) external view override returns (uint256) {
        string memory symbol = ImTokenMinimal(ImTokenMinimal(mToken).underlying()).symbol();
        PriceConfig memory config = configs[symbol];
        uint256 priceUsd = _getPriceUSD(symbol);
        return priceUsd * 10 ** (18 - config.underlyingDecimals);
    }

    // ----------- CORE LOGIC ------------
    function _getPriceUSD(string memory symbol) internal view returns (uint256) {
        PriceConfig memory config = configs[symbol];
        if (config.api3Feed == address(0) || config.eOracleFeed == address(0)) {
            revert MixedPriceOracle_MissingFeed();
        }

        // compute full USD prices from both oracle sources
        (uint256 api3Usd, uint256 api3LastUpdate) = _getApi3Price(symbol);
        (uint256 eOracleUsd, uint256 eOracleLastUpdate) = _geteOraclePrice(symbol);

        // delta
        uint256 delta = _absDiff(int256(api3Usd), int256(eOracleUsd));
        uint256 deltaBps = (delta * PRICE_DELTA_EXP) / eOracleUsd;

        uint256 deltaSymbol = deltaPerSymbol[symbol];
        if (deltaSymbol == 0) deltaSymbol = maxPriceDelta;

        // staleness
        uint256 _staleness = _getStaleness(symbol);
        bool api3Fresh = block.timestamp - api3LastUpdate <= _staleness;
        if (!api3Fresh || deltaBps > deltaSymbol) {
            require(block.timestamp - eOracleLastUpdate <= _staleness, MixedPriceOracle_eOracleStalePrice());
            return eOracleUsd;
        } else {
            require(block.timestamp - api3LastUpdate <= _staleness, MixedPriceOracle_ApiV3StalePrice());
            return api3Usd;
        }
    }

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

    function _geteOraclePrice(string memory symbol) internal view returns (uint256 price, uint256 lastUpdate) {
        PriceConfig memory config = configs[symbol];
        (, int256 eOraclePrice,, uint256 eOracleUpdatedAt,) = IDefaultAdapter(config.eOracleFeed).latestRoundData();

        uint256 decimalseOracleFeed = IDefaultAdapter(config.eOracleFeed).decimals(); 
        price = uint256(eOraclePrice) * 10 ** (18 - decimalseOracleFeed);
        lastUpdate = eOracleUpdatedAt;

        if (keccak256(abi.encodePacked(config.toSymbol)) != keccak256(abi.encodePacked("USD"))) {
            (uint256 eOracleCrtPrice, uint256 parentUpdate) = _geteOraclePrice(config.toSymbol);
            price = (price * eOracleCrtPrice) / 1e18;

            if (parentUpdate < lastUpdate) {
                lastUpdate = parentUpdate;
            }
        }
    }

    // ----------- HELPERS ------------
    function _absDiff(int256 a, int256 b) internal pure returns (uint256) {
        return uint256(a >= b ? a - b : b - a);
    }

    function _getStaleness(string memory symbol) internal view returns (uint256) {
        uint256 _registered = stalenessPerSymbol[symbol];
        return _registered > 0 ? _registered : STALENESS_PERIOD;
    }
}
