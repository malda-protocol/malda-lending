// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {MixedPriceOracleV4} from "src/oracles/MixedPriceOracleV4.sol";

/// @title SetPriceFeedOnOracleV4
/// @notice Function-call script that sets oracle feed configs on MixedPriceOracleV4 in single or batch mode
contract SetPriceFeedOnOracleV4 is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the oracle
        address oracle;
        /// @notice Whether to execute in single-mode update flow
        bool useSingleMode;
        /// @notice The single-mode symbol
        string singleSymbol;
        /// @notice The single-mode API3 feed address
        address singleApi3Feed;
        /// @notice The single-mode Chainlink feed address
        address singleChainlinkFeed;
        /// @notice The single-mode API3 quote symbol
        string singleApi3ToSymbol;
        /// @notice The single-mode Chainlink quote symbol
        string singleChainlinkToSymbol;
        /// @notice The single-mode underlying decimals
        uint256 singleUnderlyingDecimals;
        /// @notice The list of symbols for batch mode
        string[] symbols;
        /// @notice The list of API3 feed addresses for batch mode
        address[] api3Feeds;
        /// @notice The list of Chainlink feed addresses for batch mode
        address[] chainlinkFeeds;
        /// @notice The list of API3 quote symbols for batch mode
        string[] api3ToSymbols;
        /// @notice The list of Chainlink quote symbols for batch mode
        string[] chainlinkToSymbols;
        /// @notice The list of underlying decimals for batch mode
        uint256[] underlyingDecimals;
    }

    struct FeedConfig {
        /// @notice The asset symbol
        string symbol;
        /// @notice The API3 feed address
        address api3Feed;
        /// @notice The Chainlink feed address
        address chainlinkFeed;
        /// @notice The API3 quote symbol
        string api3ToSymbol;
        /// @notice The Chainlink quote symbol
        string chainlinkToSymbol;
        /// @notice The underlying token decimals for this symbol
        uint256 underlyingDecimals;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the oracle is invalid
    error InvalidOracle();
    /// @notice Error thrown when single-mode config is invalid
    error InvalidSingleModeConfig();
    /// @notice Error thrown when batch-mode config is invalid
    error InvalidBatchModeConfig();
    /// @notice Error thrown when symbol is invalid at index
    error InvalidSymbolAtIndex(uint256 index);
    /// @notice Error thrown when API3 feed is invalid at index
    error InvalidApi3FeedAtIndex(uint256 index);
    /// @notice Error thrown when oracle config read fails
    error OracleConfigReadFailed();
    /// @notice Error thrown when oracle config mismatch occurs
    error OracleConfigMismatch();

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////
    /// @inheritdoc FunctionCallScriptBase
    function _callFunctionAndAssertResult(bytes memory deployConfig)
        internal
        override
        returns (bool success, bytes memory err)
    {
        // Effects: decode validated runtime config
        DeployConfig memory cfg = abi.decode(deployConfig, (DeployConfig));

        if (cfg.useSingleMode) {
            FeedConfig memory feed = FeedConfig({
                symbol: cfg.singleSymbol,
                api3Feed: cfg.singleApi3Feed,
                chainlinkFeed: cfg.singleChainlinkFeed,
                api3ToSymbol: cfg.singleApi3ToSymbol,
                chainlinkToSymbol: cfg.singleChainlinkToSymbol,
                underlyingDecimals: cfg.singleUnderlyingDecimals
            });

            return _setAndAssertFeed(cfg.oracle, feed);
        }

        uint256 length = cfg.symbols.length;
        for (uint256 i; i < length; ++i) {
            FeedConfig memory feed = FeedConfig({
                symbol: cfg.symbols[i],
                api3Feed: cfg.api3Feeds[i],
                chainlinkFeed: cfg.chainlinkFeeds[i],
                api3ToSymbol: cfg.api3ToSymbols[i],
                chainlinkToSymbol: cfg.chainlinkToSymbols[i],
                underlyingDecimals: cfg.underlyingDecimals[i]
            });

            (success, err) = _setAndAssertFeed(cfg.oracle, feed);
            if (!success) {
                return (false, err);
            }
        }

        return (true, bytes(""));
    }

    /// @notice Sets one feed config and asserts resulting onchain state
    function _setAndAssertFeed(address oracle, FeedConfig memory feed)
        internal
        returns (bool success, bytes memory err)
    {
        (bool readBeforeSuccess, FeedConfig memory currentConfig) = _readConfig(oracle, feed.symbol);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(OracleConfigReadFailed.selector));
        }

        if (_isSameConfig(currentConfig, feed)) {
            return (true, bytes(""));
        }

        MixedPriceOracleV4.PriceConfig memory expectedConfig = MixedPriceOracleV4.PriceConfig({
            api3Feed: feed.api3Feed,
            chainlinkFeed: feed.chainlinkFeed,
            api3ToSymbol: feed.api3ToSymbol,
            chainlinkToSymbol: feed.chainlinkToSymbol,
            underlyingDecimals: feed.underlyingDecimals
        });
        bytes memory callData =
            abi.encodeWithSelector(MixedPriceOracleV4.setConfig.selector, feed.symbol, expectedConfig);
        Logger.logCalldata("MixedPriceOracleV4", oracle, "setConfig", callData);
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(oracle).call(callData);
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, FeedConfig memory updatedConfig) = _readConfig(oracle, feed.symbol);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(OracleConfigReadFailed.selector));
        }

        if (!_isSameConfig(updatedConfig, feed)) {
            return (false, abi.encodeWithSelector(OracleConfigMismatch.selector));
        }

        return (true, bytes(""));
    }

    /// @inheritdoc ScriptBase
    function _serializeConfig(bytes memory config, string memory namespace_)
        internal
        override
        returns (string memory serialized)
    {
        // Effects: decode final config for output serialization
        DeployConfig memory cfg = abi.decode(config, (DeployConfig));
        // Effects: serialize final resolved config under script namespace
        string memory json = namespace_;
        vm.serializeAddress(json, "oracle", cfg.oracle);
        vm.serializeBool(json, "useSingleMode", cfg.useSingleMode);
        vm.serializeString(json, "singleSymbol", cfg.singleSymbol);
        vm.serializeAddress(json, "singleApi3Feed", cfg.singleApi3Feed);
        vm.serializeAddress(json, "singleChainlinkFeed", cfg.singleChainlinkFeed);
        vm.serializeString(json, "singleApi3ToSymbol", cfg.singleApi3ToSymbol);
        vm.serializeString(json, "singleChainlinkToSymbol", cfg.singleChainlinkToSymbol);
        vm.serializeUint(json, "singleUnderlyingDecimals", cfg.singleUnderlyingDecimals);
        vm.serializeString(json, "symbols", cfg.symbols);
        vm.serializeAddress(json, "api3Feeds", cfg.api3Feeds);
        vm.serializeAddress(json, "chainlinkFeeds", cfg.chainlinkFeeds);
        vm.serializeString(json, "api3ToSymbols", cfg.api3ToSymbols);
        vm.serializeString(json, "chainlinkToSymbols", cfg.chainlinkToSymbols);
        vm.serializeUint(json, "underlyingDecimals", cfg.underlyingDecimals);
        serialized = vm.serializeUint(json, "batchSize", cfg.symbols.length);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.oracle = _readAndLogAddress(json, "oracle");
        cfg.useSingleMode = _readAndLogBool(json, "useSingleMode");
        cfg.singleSymbol = _readAndLogString(json, "singleSymbol");
        cfg.singleApi3Feed = _readAndLogAddress(json, "singleApi3Feed");
        cfg.singleChainlinkFeed = _readAndLogAddress(json, "singleChainlinkFeed");
        cfg.singleApi3ToSymbol = _readAndLogString(json, "singleApi3ToSymbol");
        cfg.singleChainlinkToSymbol = _readAndLogString(json, "singleChainlinkToSymbol");
        cfg.singleUnderlyingDecimals = _readAndLogUint(json, "singleUnderlyingDecimals");
        cfg.symbols = _readAndLogStringArray(json, "symbols");
        cfg.api3Feeds = _readAndLogAddressArray(json, "api3Feeds");
        cfg.chainlinkFeeds = _readAndLogAddressArray(json, "chainlinkFeeds");
        cfg.api3ToSymbols = _readAndLogStringArray(json, "api3ToSymbols");
        cfg.chainlinkToSymbols = _readAndLogStringArray(json, "chainlinkToSymbols");
        cfg.underlyingDecimals = _readAndLogUintArray(json, "underlyingDecimals");

        require(cfg.oracle != address(0), InvalidOracle());

        if (cfg.useSingleMode) {
            require(
                bytes(cfg.singleSymbol).length > 0 && cfg.singleApi3Feed != address(0)
                    && bytes(cfg.singleApi3ToSymbol).length > 0 && bytes(cfg.singleChainlinkToSymbol).length > 0,
                InvalidSingleModeConfig()
            );

            deployConfig = abi.encode(cfg);
            return deployConfig;
        }

        uint256 length = cfg.symbols.length;
        require(
            length > 0 && cfg.api3Feeds.length == length && cfg.chainlinkFeeds.length == length
                && cfg.api3ToSymbols.length == length && cfg.chainlinkToSymbols.length == length
                && cfg.underlyingDecimals.length == length,
            InvalidBatchModeConfig()
        );

        for (uint256 i; i < length; ++i) {
            require(bytes(cfg.symbols[i]).length > 0, InvalidSymbolAtIndex(i));
            require(cfg.api3Feeds[i] != address(0), InvalidApi3FeedAtIndex(i));
        }

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readConfig(address oracle, string memory symbol)
        internal
        view
        returns (bool success, FeedConfig memory cfg)
    {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(oracle).staticcall(abi.encodeWithSignature("configs(string)", symbol));

        if (!callSuccess || data.length == 0) {
            return (false, cfg);
        }

        (cfg.api3Feed, cfg.chainlinkFeed, cfg.api3ToSymbol, cfg.chainlinkToSymbol, cfg.underlyingDecimals) =
            abi.decode(data, (address, address, string, string, uint256));
        cfg.symbol = symbol;

        return (true, cfg);
    }

    /// @notice Compares two feed configs for equality
    function _isSameConfig(FeedConfig memory a, FeedConfig memory b) internal pure returns (bool) {
        return a.api3Feed == b.api3Feed && a.chainlinkFeed == b.chainlinkFeed
            && keccak256(bytes(a.api3ToSymbol)) == keccak256(bytes(b.api3ToSymbol))
            && keccak256(bytes(a.chainlinkToSymbol)) == keccak256(bytes(b.chainlinkToSymbol))
            && a.underlyingDecimals == b.underlyingDecimals;
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setPriceFeedOnOracleV4";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetPriceFeedOnOracleV4.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetPriceFeedOnOracleV4.output.json";
    }
}
