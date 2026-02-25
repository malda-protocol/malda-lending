// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetPriceOracleOnOperator
/// @notice Function-call script that sets oracle on Operator
contract SetPriceOracleOnOperator is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator contract
        address operator;
        /// @notice The address of the oracle
        address oracle;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when the oracle is invalid
    error InvalidOracle();
    /// @notice Error thrown when oracle read fails
    error OracleReadFailed();
    /// @notice Error thrown when oracle mismatch occurs
    error OracleMismatch(address expected, address actual);

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

        (bool readBeforeSuccess, address currentOracle) = _readOracle(cfg.operator);
        // Requirements: pre-call state read should succeed.
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(OracleReadFailed.selector));
        }

        // Effects: short-circuit when requested value is already set if current oracle already equals cfg.oracle.
        if (currentOracle == cfg.oracle) {
            return (true, bytes(""));
        }

        bytes memory callData = abi.encodeWithSelector(Operator.setPriceOracle.selector, cfg.oracle);
        Logger.logCalldata("Operator", cfg.operator, "setPriceOracle", callData);

        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.operator).call(callData);

        // Requirements: external call should succeed.
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, address updatedOracle) = _readOracle(cfg.operator);
        // Requirements: post-call state read should succeed.
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(OracleReadFailed.selector));
        }

        // Requirements: updated oracle should equal cfg.oracle after the call.
        if (updatedOracle != cfg.oracle) {
            return (false, abi.encodeWithSelector(OracleMismatch.selector, cfg.oracle, updatedOracle));
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
        serialized = vm.serializeAddress(json, "oracle", cfg.oracle);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.oracle = _readAndLogAddress(json, "oracle");

        // Requirements: cfg.operator should not be the zero address; cfg.oracle should not be the zero address.
        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.oracle != address(0), InvalidOracle());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readOracle(address operator) internal view returns (bool success, address oracle) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("oracleOperator()"));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, address(0));
        }

        // Effects: decode returned state value from payload
        oracle = abi.decode(data, (address));
        return (true, oracle);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setPriceOracleOnOperator";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetPriceOracleOnOperator.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetPriceOracleOnOperator.output.json";
    }
}
