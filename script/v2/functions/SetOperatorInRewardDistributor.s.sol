// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {RewardDistributor} from "src/rewards/RewardDistributor.sol";

/// @title SetOperatorInRewardDistributor
/// @notice Function-call script that sets operator on RewardDistributor
contract SetOperatorInRewardDistributor is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator contract
        address operator;
        /// @notice The address of the reward distributor
        address rewardDistributor;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when the reward distributor is invalid
    error InvalidRewardDistributor();
    /// @notice Error thrown when operator read fails
    error OperatorReadFailed();
    /// @notice Error thrown when operator mismatch occurs
    error OperatorMismatch(address expected, address actual);

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

        (bool readBeforeSuccess, address currentOperator) = _readOperator(cfg.rewardDistributor);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(OperatorReadFailed.selector));
        }

        // Effects: short-circuit when requested value is already set
        if (currentOperator == cfg.operator) {
            return (true, bytes(""));
        }
        bytes memory callData = abi.encodeWithSelector(RewardDistributor.setOperator.selector, cfg.operator);
        Logger.logCalldata("RewardDistributor", cfg.rewardDistributor, "setOperator", callData);
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.rewardDistributor).call(callData);
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, address updatedOperator) = _readOperator(cfg.rewardDistributor);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(OperatorReadFailed.selector));
        }

        // Requirements: resulting onchain state must match requested value
        if (updatedOperator != cfg.operator) {
            return (false, abi.encodeWithSelector(OperatorMismatch.selector, cfg.operator, updatedOperator));
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
        serialized = vm.serializeAddress(json, "rewardDistributor", cfg.rewardDistributor);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.rewardDistributor = _readAndLogAddress(json, "rewardDistributor");

        require(cfg.operator != address(0), InvalidOperator());
        require(cfg.rewardDistributor != address(0), InvalidRewardDistributor());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readOperator(address rewardDistributor) internal view returns (bool success, address operator) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(rewardDistributor).staticcall(abi.encodeWithSignature("operator()"));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 32) {
            return (false, address(0));
        }

        // Effects: decode returned state value from payload
        operator = abi.decode(data, (address));
        return (true, operator);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setOperatorInRewardDistributor";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetOperatorInRewardDistributor.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetOperatorInRewardDistributor.output.json";
    }
}
