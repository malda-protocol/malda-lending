// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {mTokenConfiguration} from "src/mToken/mTokenConfiguration.sol";

/// @title SetBorrowRateMaxMantissa
/// @notice Function-call script that sets borrow rate max mantissa on market
contract SetBorrowRateMaxMantissa is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the market
        address market;
        /// @notice The borrow rate max mantissa value
        uint256 borrowRateMaxMantissa;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the market is invalid
    error InvalidMarket();
    /// @notice Error thrown when borrow rate max mantissa read fails
    error BorrowRateMaxMantissaReadFailed();
    /// @notice Error thrown when borrow rate max mantissa mismatch occurs
    error BorrowRateMaxMantissaMismatch(uint256 expected, uint256 actual);

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

        (bool readBeforeSuccess, uint256 currentMantissa) = _readBorrowRateMaxMantissa(cfg.market);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(BorrowRateMaxMantissaReadFailed.selector));
        }

        // Effects: short-circuit when requested value is already set
        if (currentMantissa == cfg.borrowRateMaxMantissa) {
            return (true, bytes(""));
        }
        bytes memory callData =
            abi.encodeWithSelector(mTokenConfiguration.setBorrowRateMaxMantissa.selector, cfg.borrowRateMaxMantissa);
        Logger.logCalldata("mTokenConfiguration", cfg.market, "setBorrowRateMaxMantissa", callData);
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.market).call(callData);
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, uint256 updatedMantissa) = _readBorrowRateMaxMantissa(cfg.market);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(BorrowRateMaxMantissaReadFailed.selector));
        }

        // Requirements: resulting onchain state must match requested value
        if (updatedMantissa != cfg.borrowRateMaxMantissa) {
            return (
                false,
                abi.encodeWithSelector(
                    BorrowRateMaxMantissaMismatch.selector, cfg.borrowRateMaxMantissa, updatedMantissa
                )
            );
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
        serialized = vm.serializeUint(json, "borrowRateMaxMantissa", cfg.borrowRateMaxMantissa);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.market = _readAndLogAddress(json, "market");
        cfg.borrowRateMaxMantissa = _readAndLogUint(json, "borrowRateMaxMantissa");

        require(cfg.market != address(0), InvalidMarket());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readBorrowRateMaxMantissa(address market) internal view returns (bool success, uint256 mantissa) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(market).staticcall(abi.encodeWithSignature("borrowRateMaxMantissa()"));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 32) {
            return (false, 0);
        }

        // Effects: decode returned state value from payload
        mantissa = abi.decode(data, (uint256));
        return (true, mantissa);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setBorrowRateMaxMantissa";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetBorrowRateMaxMantissa.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetBorrowRateMaxMantissa.output.json";
    }
}
