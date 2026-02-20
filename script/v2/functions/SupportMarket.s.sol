// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/v2/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SupportMarket
/// @notice Function-call script that supports a market on Operator
contract SupportMarket is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator contract
        address operator;
        /// @notice The address of the market
        address market;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when the market is invalid
    error InvalidMarket();
    /// @notice Error thrown when market read fails
    error MarketReadFailed();
    /// @notice Error thrown when market is not listed after supportMarket call
    error MarketNotListed();

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

        (bool readBeforeSuccess, bool isListedBefore) = _readMarketListed(cfg.operator, cfg.market);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(MarketReadFailed.selector));
        }

        if (isListedBefore) {
            return (true, bytes(""));
        }
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.operator).call(abi.encodeWithSelector(Operator.supportMarket.selector, cfg.market));
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, bool isListedAfter) = _readMarketListed(cfg.operator, cfg.market);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(MarketReadFailed.selector));
        }

        if (!isListedAfter) {
            return (false, abi.encodeWithSelector(MarketNotListed.selector));
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
        vm.serializeAddress(json, "operator", cfg.operator);
        serialized = vm.serializeAddress(json, "market", cfg.market);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.market = _readAndLogAddress(json, "market");

        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.market != address(0), InvalidMarket());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readMarketListed(address operator, address market) internal view returns (bool success, bool isListed) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("markets(address)", market));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 64) {
            return (false, false);
        }

        // Effects: decode returned state value from payload
        (isListed,) = abi.decode(data, (bool, uint256));
        return (true, isListed);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "supportMarket";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SupportMarket.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SupportMarket.output.json";
    }
}
