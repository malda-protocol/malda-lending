// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {Operator} from "src/Operator/Operator.sol";

/// @title SetWhitelistEnabled
/// @notice Function-call script that sets operator whitelist status and user whitelist states
contract SetWhitelistEnabled is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the Operator contract
        address operator;
        /// @notice The target whitelist enabled status
        bool whitelistEnabled;
        /// @notice The list of user addresses
        address[] users;
        /// @notice The target whitelist status for each user
        bool userStatus;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the operator is invalid
    error InvalidOperator();
    /// @notice Error thrown when the user at the provided index is invalid
    error InvalidUser(uint256 index);
    /// @notice Error thrown when whitelist status read fails
    error WhitelistStatusReadFailed();
    /// @notice Error thrown when whitelist status mismatch occurs
    error WhitelistStatusMismatch(bool expected, bool actual);
    /// @notice Error thrown when user whitelist read fails
    error UserWhitelistReadFailed(address user);
    /// @notice Error thrown when user whitelist mismatch occurs
    error UserWhitelistMismatch(address user, bool expected, bool actual);

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

        (bool readStatusSuccess, bool currentWhitelistStatus) = _readWhitelistStatus(cfg.operator);
        if (!readStatusSuccess) {
            return (false, abi.encodeWithSelector(WhitelistStatusReadFailed.selector));
        }

        bool broadcastStarted;
        if (currentWhitelistStatus != cfg.whitelistEnabled) {
            // Interactions: begin broadcast for batched state updates
            vm.startBroadcast();
            broadcastStarted = true;

            bytes memory callData = abi.encodeWithSelector(Operator.setWhitelistStatus.selector, cfg.whitelistEnabled);
            Logger.logCalldata("Operator", cfg.operator, "setWhitelistStatus", callData);
            (success, err) = address(cfg.operator).call(callData);
            if (!success) {
                vm.stopBroadcast();
                return (false, err);
            }

            (bool readAfterStatusSuccess, bool updatedWhitelistStatus) = _readWhitelistStatus(cfg.operator);
            if (!readAfterStatusSuccess) {
                vm.stopBroadcast();
                return (false, abi.encodeWithSelector(WhitelistStatusReadFailed.selector));
            }

            // Requirements: resulting onchain state must match requested value
            if (updatedWhitelistStatus != cfg.whitelistEnabled) {
                vm.stopBroadcast();
                return (
                    false,
                    abi.encodeWithSelector(
                        WhitelistStatusMismatch.selector, cfg.whitelistEnabled, updatedWhitelistStatus
                    )
                );
            }
        }

        uint256 usersLength = cfg.users.length;
        for (uint256 i; i < usersLength; ++i) {
            address user = cfg.users[i];

            (bool readUserSuccess, bool currentStatus) = _readUserStatus(cfg.operator, user);
            if (!readUserSuccess) {
                if (broadcastStarted) {
                    vm.stopBroadcast();
                }
                return (false, abi.encodeWithSelector(UserWhitelistReadFailed.selector, user));
            }

            // Effects: short-circuit when requested value is already set
            if (currentStatus == cfg.userStatus) {
                continue;
            }

            if (!broadcastStarted) {
                // Interactions: begin broadcast for batched state updates
                vm.startBroadcast();
                broadcastStarted = true;
            }

            bytes memory callData = abi.encodeWithSelector(Operator.setWhitelistedUser.selector, user, cfg.userStatus);
            Logger.logCalldata("Operator", cfg.operator, "setWhitelistedUser", callData);
            (success, err) = address(cfg.operator).call(callData);
            if (!success) {
                vm.stopBroadcast();
                return (false, err);
            }

            (bool readAfterUserSuccess, bool updatedStatus) = _readUserStatus(cfg.operator, user);
            if (!readAfterUserSuccess) {
                vm.stopBroadcast();
                return (false, abi.encodeWithSelector(UserWhitelistReadFailed.selector, user));
            }

            // Requirements: resulting onchain state must match requested value
            if (updatedStatus != cfg.userStatus) {
                vm.stopBroadcast();
                return
                    (false, abi.encodeWithSelector(UserWhitelistMismatch.selector, user, cfg.userStatus, updatedStatus));
            }
        }

        if (broadcastStarted) {
            vm.stopBroadcast();
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
        vm.serializeBool(json, "whitelistEnabled", cfg.whitelistEnabled);
        vm.serializeAddress(json, "users", cfg.users);
        vm.serializeBool(json, "userStatus", cfg.userStatus);
        serialized = vm.serializeUint(json, "usersCount", cfg.users.length);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.operator = _readAndLogAddress(json, "operator");
        cfg.whitelistEnabled = _readAndLogBool(json, "whitelistEnabled");
        cfg.users = _readAndLogAddressArray(json, "users");
        cfg.userStatus = _readAndLogBool(json, "userStatus");

        require(cfg.operator != address(0), InvalidOperator());

        uint256 usersLength = cfg.users.length;
        for (uint256 i; i < usersLength; ++i) {
            require(cfg.users[i] != address(0), InvalidUser(i));
        }

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readWhitelistStatus(address operator) internal view returns (bool success, bool status) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("whitelistEnabled()"));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 32) {
            return (false, false);
        }

        // Effects: decode returned state value from payload
        status = abi.decode(data, (bool));
        return (true, status);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readUserStatus(address operator, address user) internal view returns (bool success, bool status) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(operator).staticcall(abi.encodeWithSignature("userWhitelisted(address)", user));

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
        return "setWhitelistEnabled";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetWhitelistEnabled.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetWhitelistEnabled.output.json";
    }
}
