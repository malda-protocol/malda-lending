// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetLiquidationBonus
/// @notice Function-call script that sets market liquidation incentive
contract SetLiquidationBonus is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator.sol contract
        address operator;
        /// @notice The address of the market
        address market;
        /// @notice The liquidation incentive mantissa to set
        uint256 factor;
    }

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator address is invalid
    error InvalidOperator();
    /// @notice Error thrown when the market address is invalid
    error InvalidMarket();
    /// @notice Error thrown when the liquidation incentive read fails
    error LiquidationBonusReadFailed();
    /// @notice Error thrown when the liquidation incentive mismatch occurs
    error LiquidationBonusMismatch(uint256 expected, uint256 actual);

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

        // Interactions: read current liquidation incentive from operator
        (bool readBeforeSuccess, uint256 currentBonus) = _readLiquidationBonus(cfg.operator, cfg.market);

        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(LiquidationBonusReadFailed.selector));
        }

        // Effects: short-circuit if requested liquidation incentive is already set
        if (currentBonus == cfg.factor) {
            return (true, bytes(""));
        }
        bytes memory callData =
            abi.encodeWithSelector(Operator.setLiquidationIncentive.selector, cfg.market, cfg.factor);
        Logger.logCalldata("Operator", cfg.operator, "setLiquidationIncentive", callData);

        // Interactions: perform setLiquidationIncentive call as active broadcaster
        vm.broadcast();
        // solhint-disable avoid-low-level-calls
        (success, err) = address(cfg.operator).call(callData);
        // solhint-enable avoid-low-level-calls
        if (!success) {
            return (false, err);
        }

        // Interactions: read liquidation incentive after the call for invariant checks
        (bool readAfterSuccess, uint256 updatedBonus) = _readLiquidationBonus(cfg.operator, cfg.market);

        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(LiquidationBonusReadFailed.selector));
        }

        // Requirements: resulting onchain state must match requested liquidation incentive
        if (updatedBonus != cfg.factor) {
            return (false, abi.encodeWithSelector(LiquidationBonusMismatch.selector, cfg.factor, updatedBonus));
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

        // Requirements: validate critical config fields before execution
        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.market != address(0), InvalidMarket());

        // Effects: return encoded validated config to base runner
        deployConfig = abi.encode(cfg);
    }

    /// @notice Reads the liquidation incentive from the operator
    /// @param operator The address of the operator
    /// @param market The address of the market
    /// @return success Whether the liquidation incentive read was successful
    /// @return factor The liquidation incentive mantissa
    function _readLiquidationBonus(address operator, address market)
        internal
        view
        returns (bool success, uint256 factor)
    {
        // Interactions: query liquidation incentive using operator public getter
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("liquidationIncentiveMantissa(address)", market));

        // Requirements: staticcall must return a full uint256 payload
        if (!callSuccess || data.length < 32) {
            return (false, 0);
        }

        // Effects: decode returned liquidation incentive value
        factor = abi.decode(data, (uint256));
        return (true, factor);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setLiquidationBonus";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetLiquidationBonus.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetLiquidationBonus.output.json";
    }
}
