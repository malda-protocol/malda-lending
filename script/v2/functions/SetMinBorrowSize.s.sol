// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/v2/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetMinBorrowSize
/// @notice Function-call script that sets market min borrow size on Operator
contract SetMinBorrowSize is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator contract
        address operator;
        /// @notice The address of the market
        address market;
        /// @notice The minimum borrow size value
        uint256 size;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when the market is invalid
    error InvalidMarket();
    /// @notice Error thrown when min borrow size read fails
    error MinBorrowSizeReadFailed();
    /// @notice Error thrown when min borrow size mismatch occurs
    error MinBorrowSizeMismatch(uint256 expected, uint256 actual);

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

        (bool readBeforeSuccess, uint256 currentSize) = _readMinBorrowSize(cfg.operator, cfg.market);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(MinBorrowSizeReadFailed.selector));
        }

        // Effects: short-circuit when requested value is already set
        if (currentSize == cfg.size) {
            return (true, bytes(""));
        }

        // Effects: prepare single-market arrays for operator batch setter
        address[] memory mTokens = new address[](1);
        uint256[] memory sizes = new uint256[](1);
        mTokens[0] = cfg.market;
        sizes[0] = cfg.size;
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) =
            address(cfg.operator).call(abi.encodeWithSelector(Operator.setBorrowSizeMin.selector, mTokens, sizes));
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, uint256 updatedSize) = _readMinBorrowSize(cfg.operator, cfg.market);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(MinBorrowSizeReadFailed.selector));
        }

        // Requirements: resulting onchain state must match requested value
        if (updatedSize != cfg.size) {
            return (false, abi.encodeWithSelector(MinBorrowSizeMismatch.selector, cfg.size, updatedSize));
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
        vm.serializeAddress(json, "market", cfg.market);
        serialized = vm.serializeUint(json, "size", cfg.size);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.market = _readAndLogAddress(json, "market");
        cfg.size = _readAndLogUint(json, "size");

        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.market != address(0), InvalidMarket());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readMinBorrowSize(address operator, address market) internal view returns (bool success, uint256 size) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("minBorrowSize(address)", market));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 32) {
            return (false, 0);
        }

        // Effects: decode returned state value from payload
        size = abi.decode(data, (uint256));
        return (true, size);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setMinBorrowSize";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetMinBorrowSize.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetMinBorrowSize.output.json";
    }
}
