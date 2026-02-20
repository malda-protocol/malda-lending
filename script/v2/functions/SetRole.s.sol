// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/v2/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

import {Roles} from "src/Roles.sol";

/// @title SetRole
/// @notice Function-call script that sets role allowance in Roles contract
contract SetRole is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Roles contract
        address rolesContract;
        /// @notice The receiver address
        address receiver;
        /// @notice The role identifier
        bytes32 role;
        /// @notice The target status value
        bool status;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the roles contract is invalid
    error InvalidRolesContract();
    /// @notice Error thrown when the receiver is invalid
    error InvalidReceiver();
    /// @notice Error thrown when the role is invalid
    error InvalidRole();
    /// @notice Error thrown when role read fails
    error RoleReadFailed();
    /// @notice Error thrown when role mismatch occurs
    error RoleMismatch(bool expected, bool actual);

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

        (bool readBeforeSuccess, bool currentStatus) = _readRoleStatus(cfg.rolesContract, cfg.receiver, cfg.role);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(RoleReadFailed.selector));
        }

        // Effects: short-circuit when requested value is already set
        if (currentStatus == cfg.status) {
            return (true, bytes(""));
        }
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.rolesContract)
            .call(abi.encodeWithSelector(Roles.allowFor.selector, cfg.receiver, cfg.role, cfg.status));
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, bool updatedStatus) = _readRoleStatus(cfg.rolesContract, cfg.receiver, cfg.role);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(RoleReadFailed.selector));
        }

        // Requirements: resulting onchain state must match requested value
        if (updatedStatus != cfg.status) {
            return (false, abi.encodeWithSelector(RoleMismatch.selector, cfg.status, updatedStatus));
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
        vm.serializeAddress(json, "rolesContract", cfg.rolesContract);
        vm.serializeAddress(json, "receiver", cfg.receiver);
        vm.serializeBytes32(json, "role", cfg.role);
        serialized = vm.serializeBool(json, "status", cfg.status);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.rolesContract = _readAndLogAddress(json, "rolesContract");
        cfg.receiver = _readAndLogAddress(json, "receiver");
        cfg.role = _readAndLogBytes32(json, "role");
        cfg.status = _readAndLogBool(json, "status");

        require(cfg.rolesContract != address(0), InvalidRolesContract());
        require(cfg.receiver != address(0), InvalidReceiver());
        require(cfg.role != bytes32(0), InvalidRole());

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readRoleStatus(address rolesContract, address receiver, bytes32 role)
        internal
        view
        returns (bool success, bool status)
    {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(rolesContract).staticcall(abi.encodeWithSignature("isAllowedFor(address,bytes32)", receiver, role));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 32) {
            return (false, false);
        }

        // Effects: decode returned state value from payload
        status = abi.decode(data, (bool));
        return (true, status);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setRole";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetRole.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetRole.output.json";
    }
}
