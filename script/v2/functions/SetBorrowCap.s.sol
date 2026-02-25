// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetBorrowCap
/// @notice Function-call script that sets market borrow cap on Operator
contract SetBorrowCap is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator contract
        address operator;
        /// @notice The address of the market
        address market;
        /// @notice The cap value
        uint256 cap;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when the market is invalid
    error InvalidMarket();
    /// @notice Error thrown when borrow cap read fails
    error BorrowCapReadFailed();
    /// @notice Error thrown when borrow cap mismatch occurs
    error BorrowCapMismatch(uint256 expected, uint256 actual);

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

        (bool readBeforeSuccess, uint256 currentCap) = _readBorrowCap(cfg.operator, cfg.market);
        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(BorrowCapReadFailed.selector));
        }

        // Effects + Requirements: short-circuit when requested value is already set; skip mutation when current cap already
        // equals cfg.cap.
        if (currentCap == cfg.cap) {
            return (true, bytes(""));
        }

        // Effects: prepare single-market arrays for operator batch setter
        address[] memory mTokens = new address[](1);
        uint256[] memory caps = new uint256[](1);
        mTokens[0] = cfg.market;
        caps[0] = cfg.cap;
        bytes memory callData = abi.encodeWithSelector(Operator.setMarketBorrowCaps.selector, mTokens, caps);
        Logger.logCalldata("Operator", cfg.operator, "setMarketBorrowCaps", callData);
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.operator).call(callData);
        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, uint256 updatedCap) = _readBorrowCap(cfg.operator, cfg.market);
        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(BorrowCapReadFailed.selector));
        }

        // Requirements: updated cap should equal cfg.cap after the call.
        if (updatedCap != cfg.cap) {
            return (false, abi.encodeWithSelector(BorrowCapMismatch.selector, cfg.cap, updatedCap));
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
        serialized = vm.serializeUint(json, "cap", cfg.cap);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.market = _readAndLogAddress(json, "market");
        cfg.cap = _readAndLogUint(json, "cap");

        // Requirements: cfg.operator should not be the zero address; cfg.market should not be the zero address.
        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.market != address(0), InvalidMarket());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readBorrowCap(address operator, address market) internal view returns (bool success, uint256 cap) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("borrowCaps(address)", market));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, 0);
        }

        // Effects: decode returned state value from payload
        cap = abi.decode(data, (uint256));
        return (true, cap);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setBorrowCap";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetBorrowCap.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetBorrowCap.output.json";
    }
}
