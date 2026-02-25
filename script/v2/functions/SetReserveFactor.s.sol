// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {mTokenConfiguration} from "src/mToken/mTokenConfiguration.sol";

/// @title SetReserveFactor
/// @notice Function-call script that sets market reserve factor
contract SetReserveFactor is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the market
        address market;
        /// @notice The factor mantissa value
        uint256 factor;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the market is invalid
    error InvalidMarket();
    /// @notice Error thrown when reserve factor read fails
    error ReserveFactorReadFailed();
    /// @notice Error thrown when reserve factor mismatch occurs
    error ReserveFactorMismatch(uint256 expected, uint256 actual);

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

        (bool readBeforeSuccess, uint256 currentFactor) = _readReserveFactor(cfg.market);
        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(ReserveFactorReadFailed.selector));
        }

        // Effects + Requirements: short-circuit when requested value is already set; skip mutation when current factor already
        // equals cfg.factor.
        if (currentFactor == cfg.factor) {
            return (true, bytes(""));
        }
        bytes memory callData = abi.encodeWithSelector(mTokenConfiguration.setReserveFactor.selector, cfg.factor);
        Logger.logCalldata("mTokenConfiguration", cfg.market, "setReserveFactor", callData);
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.market).call(callData);
        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, uint256 updatedFactor) = _readReserveFactor(cfg.market);
        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(ReserveFactorReadFailed.selector));
        }

        // Requirements: updated factor should equal cfg.factor after the call.
        if (updatedFactor != cfg.factor) {
            return (false, abi.encodeWithSelector(ReserveFactorMismatch.selector, cfg.factor, updatedFactor));
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
        vm.serializeAddress(json, "market", cfg.market);
        serialized = vm.serializeUint(json, "factor", cfg.factor);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.market = _readAndLogAddress(json, "market");
        cfg.factor = _readAndLogUint(json, "factor");

        // Requirement: cfg.market should not be the zero address.
        require(cfg.market != address(0), InvalidMarket());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readReserveFactor(address market) internal view returns (bool success, uint256 factor) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(market).staticcall(abi.encodeWithSignature("reserveFactorMantissa()"));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, 0);
        }

        // Effects: decode returned state value from payload
        factor = abi.decode(data, (uint256));
        return (true, factor);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setReserveFactor";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetReserveFactor.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetReserveFactor.output.json";
    }
}
