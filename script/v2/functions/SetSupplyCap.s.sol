// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetSupplyCap
/// @notice Function-call script that sets market supply cap using FunctionCallScriptBase pattern
contract SetSupplyCap is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator.sol contract
        address operator;
        /// @notice The address of the market
        address market;
        /// @notice The supply cap
        uint256 cap;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator address is invalid
    error InvalidOperator();
    /// @notice Error thrown when the market address is invalid
    error InvalidMarket();
    /// @notice Error thrown when the supply cap read fails
    error SupplyCapReadFailed();
    /// @notice Error thrown when the supply cap mismatch occurs
    error SupplyCapMismatch(uint256 expected, uint256 actual);

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

        // Interactions: read current cap from operator
        (bool readBeforeSuccess, uint256 currentCap) = _readSupplyCap(cfg.operator, cfg.market);

        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(SupplyCapReadFailed.selector));
        }

        // Effects + Requirements: short-circuit if requested cap already set; skip mutation when current cap already equals
        // cfg.cap.
        if (currentCap == cfg.cap) {
            return (true, bytes(""));
        }

        // Effects: prepare single-market input arrays
        address[] memory mTokens = new address[](1);
        uint256[] memory caps = new uint256[](1);
        mTokens[0] = cfg.market;
        caps[0] = cfg.cap;
        bytes memory callData = abi.encodeWithSelector(Operator.setMarketSupplyCaps.selector, mTokens, caps);
        Logger.logCalldata("Operator", cfg.operator, "setMarketSupplyCaps", callData);

        // Interactions: perform setMarketSupplyCaps call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.operator).call(callData);

        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        // Interactions: read cap after the call for invariant checks
        (bool readAfterSuccess, uint256 updatedCap) = _readSupplyCap(cfg.operator, cfg.market);

        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(SupplyCapReadFailed.selector));
        }

        // Requirements: updated cap should equal cfg.cap after the call.
        if (updatedCap != cfg.cap) {
            return (false, abi.encodeWithSelector(SupplyCapMismatch.selector, cfg.cap, updatedCap));
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

        // Read config: operator, market, cap
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.market = _readAndLogAddress(json, "market");
        cfg.cap = _readAndLogUint(json, "cap");

        // Requirements: cfg.operator should not be the zero address; cfg.market should not be the zero address.
        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.market != address(0), InvalidMarket());

        // Effects: return encoded validated config to base runner
        deployConfig = abi.encode(cfg);
    }

    /// @notice Reads the supply cap from the operator
    /// @param operator The address of the operator
    /// @param market The address of the market
    /// @return success Whether the supply cap read was successful
    /// @return cap The supply cap
    function _readSupplyCap(address operator, address market) internal view returns (bool success, uint256 cap) {
        // Interactions: query supply cap using operator public getter
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("supplyCaps(address)", market));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, 0);
        }

        // Effects: decode returned cap value
        cap = abi.decode(data, (uint256));
        return (true, cap);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setSupplyCap";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetSupplyCap.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetSupplyCap.output.json";
    }
}
