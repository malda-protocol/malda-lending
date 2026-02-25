// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {IDefaultAdapter} from "src/interfaces/IDefaultAdapter.sol";
import {MixedPriceOracleV3} from "src/oracles/MixedPriceOracleV3.sol";

/// @title SetPriceFeedOnOracle
/// @notice Function-call script that sets a single symbol feed config on MixedPriceOracleV3
contract SetPriceFeedOnOracle is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the MixedPriceOracleV3 contract
        address oracle;
        /// @notice The symbol key used by oracle config mapping
        string symbol;
        /// @notice The price feed address used as default feed
        address priceFeed;
        /// @notice The quote symbol for this feed config
        string toSymbol;
        /// @notice Underlying token decimals used by the oracle config
        uint256 underlyingDecimals;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the oracle address is invalid
    error InvalidOracle();
    /// @notice Error thrown when the symbol is empty
    error InvalidSymbol();
    /// @notice Error thrown when the price feed address is invalid
    error InvalidPriceFeed();
    /// @notice Error thrown when the quote symbol is empty
    error InvalidToSymbol();
    /// @notice Error thrown when oracle config read fails
    error OracleConfigReadFailed();
    /// @notice Error thrown when oracle config mismatches expected values
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

        // Interactions: read current config from oracle
        (bool readBeforeSuccess, IDefaultAdapter.PriceConfig memory currentConfig) =
            _readConfig(cfg.oracle, cfg.symbol, cfg.underlyingDecimals);

        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(OracleConfigReadFailed.selector));
        }

        // Effects: construct expected config from validated input
        IDefaultAdapter.PriceConfig memory expectedConfig = IDefaultAdapter.PriceConfig({
            defaultFeed: cfg.priceFeed, toSymbol: cfg.toSymbol, underlyingDecimals: cfg.underlyingDecimals
        });

        // Effects + Requirements: short-circuit when current config already matches expected values; skip mutation when current
        // config already matches expected config.
        if (_isSameConfig(currentConfig, expectedConfig)) {
            return (true, bytes(""));
        }
        bytes memory callData =
            abi.encodeWithSelector(MixedPriceOracleV3.setConfig.selector, cfg.symbol, expectedConfig);
        Logger.logCalldata("MixedPriceOracleV3", cfg.oracle, "setConfig", callData);

        // Interactions: perform setConfig call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.oracle).call(callData);

        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        // Interactions: read config after the call for invariant checks
        (bool readAfterSuccess, IDefaultAdapter.PriceConfig memory updatedConfig) =
            _readConfig(cfg.oracle, cfg.symbol, cfg.underlyingDecimals);

        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(OracleConfigReadFailed.selector));
        }

        // Requirements: updated config should match expected config after the call.
        if (!_isSameConfig(updatedConfig, expectedConfig)) {
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
        vm.serializeString(json, "symbol", cfg.symbol);
        vm.serializeAddress(json, "priceFeed", cfg.priceFeed);
        vm.serializeString(json, "toSymbol", cfg.toSymbol);
        serialized = vm.serializeUint(json, "underlyingDecimals", cfg.underlyingDecimals);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;

        // Read config: oracle, symbol, feed, quote symbol, decimals
        cfg.oracle = _readAndLogAddress(json, "oracle");
        cfg.symbol = _readAndLogString(json, "symbol");
        cfg.priceFeed = _readAndLogAddress(json, "priceFeed");
        cfg.toSymbol = _readAndLogString(json, "toSymbol");
        cfg.underlyingDecimals = _readAndLogUint(json, "underlyingDecimals");

        // Requirement: all conditions must be satisfied
        require(cfg.oracle != address(0), InvalidOracle());
        require(bytes(cfg.symbol).length > 0, InvalidSymbol());
        require(cfg.priceFeed != address(0), InvalidPriceFeed());
        require(bytes(cfg.toSymbol).length > 0, InvalidToSymbol());

        // Effects: return encoded validated config to base runner
        deployConfig = abi.encode(cfg);
    }

    /// @notice Reads the oracle price config for a symbol
    /// @param oracle The address of the oracle
    /// @param symbol The symbol key used by configs mapping
    /// @param fallbackUnderlyingDecimals Fallback decimals when oracle config has zero decimals
    /// @return success Whether config read was successful
    /// @return cfg The normalized price config
    function _readConfig(address oracle, string memory symbol, uint256 fallbackUnderlyingDecimals)
        internal
        view
        returns (bool success, IDefaultAdapter.PriceConfig memory cfg)
    {
        // Interactions: query oracle config mapping for the symbol
        (bool callSuccess, bytes memory data) =
            address(oracle).staticcall(abi.encodeWithSignature("configs(string)", symbol));

        // Requirements: read call should succeed and return non-empty data.
        if (!callSuccess || data.length == 0) {
            return (false, cfg);
        }

        // Effects: decode raw config payload
        (address defaultFeed, string memory toSymbol, uint256 underlyingDecimals) =
            abi.decode(data, (address, string, uint256));

        // Effects: normalize decimals for comparison safety
        cfg = IDefaultAdapter.PriceConfig({
            defaultFeed: defaultFeed,
            toSymbol: toSymbol,
            underlyingDecimals: underlyingDecimals > 0 ? underlyingDecimals : fallbackUnderlyingDecimals
        });

        return (true, cfg);
    }

    /// @notice Compares two oracle price configs
    /// @param a The first config
    /// @param b The second config
    /// @return isEqual Whether the two configs match
    function _isSameConfig(IDefaultAdapter.PriceConfig memory a, IDefaultAdapter.PriceConfig memory b)
        internal
        pure
        returns (bool isEqual)
    {
        return a.defaultFeed == b.defaultFeed && keccak256(bytes(a.toSymbol)) == keccak256(bytes(b.toSymbol))
            && a.underlyingDecimals == b.underlyingDecimals;
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setPriceFeedOnOracle";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetPriceFeedOnOracle.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetPriceFeedOnOracle.output.json";
    }
}
