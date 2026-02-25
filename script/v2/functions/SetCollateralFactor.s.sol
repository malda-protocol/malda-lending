// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetCollateralFactor
/// @notice Function-call script that sets market collateral factor
contract SetCollateralFactor is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator.sol contract
        address operator;
        /// @notice The address of the market
        address market;
        /// @notice The collateral factor mantissa to set
        uint256 factor;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator address is invalid
    error InvalidOperator();
    /// @notice Error thrown when the market address is invalid
    error InvalidMarket();
    /// @notice Error thrown when the collateral factor read fails
    error CollateralFactorReadFailed();
    /// @notice Error thrown when the collateral factor mismatch occurs
    error CollateralFactorMismatch(uint256 expected, uint256 actual);

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

        // Interactions: read current collateral factor from operator
        (bool readBeforeSuccess, uint256 currentFactor) = _readCollateralFactor(cfg.operator, cfg.market);

        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(CollateralFactorReadFailed.selector));
        }

        // Effects + Requirements: short-circuit if requested collateral factor is already set; skip mutation when current factor
        // already equals cfg.factor.
        if (currentFactor == cfg.factor) {
            return (true, bytes(""));
        }
        bytes memory callData = abi.encodeWithSelector(Operator.setCollateralFactor.selector, cfg.market, cfg.factor);
        Logger.logCalldata("Operator", cfg.operator, "setCollateralFactor", callData);

        // Interactions: perform setCollateralFactor call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.operator).call(callData);

        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        // Interactions: read collateral factor after the call for invariant checks
        (bool readAfterSuccess, uint256 updatedFactor) = _readCollateralFactor(cfg.operator, cfg.market);

        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(CollateralFactorReadFailed.selector));
        }

        // Requirements: updated factor should equal cfg.factor after the call.
        if (updatedFactor != cfg.factor) {
            return (false, abi.encodeWithSelector(CollateralFactorMismatch.selector, cfg.factor, updatedFactor));
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
        serialized = vm.serializeUint(json, "factor", cfg.factor);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;

        // Read config: operator, market, factor
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.market = _readAndLogAddress(json, "market");
        cfg.factor = _readAndLogUint(json, "factor");

        // Requirements: cfg.operator should not be the zero address; cfg.market should not be the zero address.
        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.market != address(0), InvalidMarket());

        // Effects: return encoded validated config to base runner
        deployConfig = abi.encode(cfg);
    }

    /// @notice Reads the collateral factor from operator market data
    /// @param operator The address of the operator
    /// @param market The address of the market
    /// @return success Whether the collateral factor read was successful
    /// @return factor The collateral factor mantissa
    function _readCollateralFactor(address operator, address market)
        internal
        view
        returns (bool success, uint256 factor)
    {
        // Interactions: query market data using operator public getter
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("markets(address)", market));

        // Requirements: read call should succeed and return at least 64 bytes.
        if (!callSuccess || data.length < 64) {
            return (false, 0);
        }

        // Effects: decode returned collateral factor
        (, factor) = abi.decode(data, (bool, uint256));
        return (true, factor);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setCollateralFactor";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetCollateralFactor.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetCollateralFactor.output.json";
    }
}
