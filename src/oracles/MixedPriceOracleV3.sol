// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.

// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IRoles} from "src/interfaces/IRoles.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IOracleOperator} from "src/interfaces/IOracleOperator.sol";
import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";

/// @title MixedPriceOracleV3
/// @author Merge Layers Inc.
/// @notice Mixed price oracle contract
contract MixedPriceOracleV3 is IOracleOperator {
    // ----------- IMMUTABLES ------------
    /// @notice Staleness period
    uint256 public immutable STALENESS_PERIOD;

    /// @notice Roles contract
    IRoles public immutable ROLES;

    // ----------- STORAGE ------------
    /// @notice Mapping of symbols to price configs
    mapping(string symbol => IDefaultAdapter.PriceConfig config) public configs;

    /// @notice Mapping of symbols to staleness periods
    mapping(string symbol => uint256 staleness) public stalenessPerSymbol;

    // ----------- EVENTS ------------
    /// @notice Emitted when a configuration is set for a symbol
    /// @param symbol Symbol being configured
    /// @param config Price configuration applied
    event ConfigSet(string symbol, IDefaultAdapter.PriceConfig config);

    /// @notice Emitted when staleness is updated for a symbol
    /// @param symbol Symbol being updated
    /// @param val New staleness value
    event StalenessUpdated(string symbol, uint256 val);

    // ----------- ERRORS ------------
    /// @notice Error thrown when caller lacks required role
    error MixedPriceOracle_Unauthorized();

    /// @notice Error thrown when price is stale
    error MixedPriceOracle_StalePrice();

    /// @notice Error thrown when price returned is invalid
    error MixedPriceOracle_InvalidPrice();

    /// @notice Error thrown when price round is invalid
    error MixedPriceOracle_InvalidRound();

    /// @notice Error thrown when configuration is invalid
    error MixedPriceOracle_InvalidConfig();

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

    /// @notice Initializes the oracle with symbols, configs, roles, and default staleness
    /// @param symbols_ Array of token symbols
    /// @param configs_ Array of price configs for symbols
    /// @param roles_ Roles contract address
    /// @param stalenessPeriod_ Default staleness period
    constructor(
        string[] memory symbols_,
        IDefaultAdapter.PriceConfig[] memory configs_,
        address roles_,
        uint256 stalenessPeriod_
    ) {
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

    /// @notice Sets a custom staleness period for a symbol
    /// @param symbol Symbol to update
    /// @param val New staleness value
    function setStaleness(string calldata symbol, uint256 val) external onlyRole(ROLES.GUARDIAN_ORACLE()) {
        // Effects: set the staleness
        stalenessPerSymbol[symbol] = val;

        // Events: emit the staleness updated event
        emit StalenessUpdated(symbol, val);
    }

    /// @notice Sets a price configuration for a symbol
    /// @param symbol Symbol to configure
    /// @param config Price configuration
    function setConfig(string calldata symbol, IDefaultAdapter.PriceConfig calldata config)
        external
        onlyRole(ROLES.GUARDIAN_ORACLE())
    {
        // Requirements: the default feed is not zero
        require(config.defaultFeed != address(0), MixedPriceOracle_InvalidConfig());

        // Effects: set the price config
        configs[symbol] = config;

        // Events: emit the config set event
        emit ConfigSet(symbol, config);
    }

    /// @notice Returns underlying price for an mToken
    /// @param mToken Address of the mToken
    /// @return Price denominated in USD with 18 decimals adjusted for underlying decimals
    function getUnderlyingPrice(address mToken) external view override returns (uint256) {
        // ImTokenMinimal cast is needed for `.symbol()` call. No need to import a different interface
        string memory symbol = ImTokenMinimal(ImTokenMinimal(mToken).underlying()).symbol();
        IDefaultAdapter.PriceConfig memory config = configs[symbol];

        uint256 priceUsd = _getPriceUSD(symbol);
        return priceUsd * 10 ** (18 - config.underlyingDecimals);
    }

    /// @notice Returns price for an mToken
    /// @param mToken Address of the mToken
    /// @return Price denominated in USD with 18 decimals
    function getPrice(address mToken) public view returns (uint256) {
        string memory symbol = ImTokenMinimal(mToken).symbol();
        return _getPriceUSD(symbol);
    }

    // price is extended for operator usage based on decimals of exchangeRate
    /// @notice Returns the USD price for a symbol
    /// @param symbol Token symbol
    /// @return price Price denominated in USD with 18 decimals
    function _getPriceUSD(string memory symbol) internal view returns (uint256) {
        IDefaultAdapter.PriceConfig memory config = configs[symbol];
        (uint256 feedPrice, uint256 feedDecimals) = _getLatestPrice(symbol, config);
        uint256 price = feedPrice * 10 ** (18 - feedDecimals);

        if (keccak256(abi.encodePacked(config.toSymbol)) != keccak256(abi.encodePacked("USD"))) {
            price = (price * _getPriceUSD(config.toSymbol)) / 10 ** 18;
        }

        return price;
    }

    /// @notice Fetches the latest price from configured feeds
    /// @param symbol Token symbol
    /// @param config Price configuration for the symbol
    /// @return price Latest price from feed
    /// @return decimals Decimals returned by the feed
    function _getLatestPrice(string memory symbol, IDefaultAdapter.PriceConfig memory config)
        internal
        view
        returns (uint256, uint256)
    {
        // Requirements: the default feed is not zero
        require(config.defaultFeed != address(0), MixedPriceOracle_InvalidConfig());

        // Interactions: get the feed
        IDefaultAdapter feed = IDefaultAdapter(config.defaultFeed);

        // Interactions: get the latest price
        (, int256 price,, uint256 updatedAt,) = feed.latestRoundData();

        // Requirements: the price is not zero
        require(price > 0, MixedPriceOracle_InvalidPrice());

        // Requirements: the price is not stale
        require(block.timestamp - updatedAt < _getStaleness(symbol), MixedPriceOracle_StalePrice());

        return (uint256(price), feed.decimals());
    }

    /// @notice Returns staleness for a symbol or default if not set
    /// @param symbol Token symbol
    /// @return Staleness period in seconds
    function _getStaleness(string memory symbol) internal view returns (uint256) {
        uint256 _registered = stalenessPerSymbol[symbol];
        return _registered > 0 ? _registered : STALENESS_PERIOD;
    }

    /// @notice Ensures caller has specific role
    /// @param role Role identifier to check
    function _onlyRole(bytes32 role) internal view {
        // Requirements: the caller has the specified role
        require(ROLES.isAllowedFor(msg.sender, role), MixedPriceOracle_Unauthorized());
    }
}
