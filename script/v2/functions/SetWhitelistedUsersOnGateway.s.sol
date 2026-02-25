// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

/// @title SetWhitelistedUsersOnGateway
/// @notice Function-call script that manages gateway whitelist and users with explicit failure policy
contract SetWhitelistedUsersOnGateway is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The list of market addresses
        address[] markets;
        /// @notice The list of user addresses
        address[] users;
        /// @notice The list of market addresses to skip
        address[] skipMarkets;
        /// @notice The target whitelist enabled status
        bool whitelistEnabled;
        /// @notice The target whitelist status for each user
        bool userStatus;
        /// @notice Whether execution continues when an operation fails
        bool continueOnFailure;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when markets array is empty
    error EmptyMarkets();
    /// @notice Error thrown when the market is invalid
    error InvalidMarket(uint256 index);
    /// @notice Error thrown when the user at the provided index is invalid
    error InvalidUser(uint256 index);
    /// @notice Error thrown when whitelist status read fails
    error WhitelistStatusReadFailed();
    /// @notice Error thrown when whitelist status mismatch occurs
    error WhitelistStatusMismatch();
    /// @notice Error thrown when user whitelist read fails
    error UserWhitelistReadFailed();
    /// @notice Error thrown when user whitelist mismatch occurs
    error UserWhitelistMismatch();

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

        bool broadcastStarted;
        uint256 marketsLength = cfg.markets.length;
        for (uint256 i; i < marketsLength; ++i) {
            address market = cfg.markets[i];
            if (_isSkipped(market, cfg.skipMarkets)) {
                continue;
            }

            (bool readStatusSuccess, bool currentWhitelistStatus) = _readWhitelistStatus(market);
            // Requirements: whitelist status read should succeed.
            if (!readStatusSuccess) {
                if (!cfg.continueOnFailure) {
                    if (broadcastStarted) {
                        vm.stopBroadcast();
                    }
                    return (false, abi.encodeWithSelector(WhitelistStatusReadFailed.selector));
                }
                continue;
            }

            if (currentWhitelistStatus != cfg.whitelistEnabled) {
                if (!broadcastStarted) {
                    // Interactions: begin broadcast for batched state updates
                    vm.startBroadcast();
                    broadcastStarted = true;
                }

                (success, err) = _setWhitelistStatus(market, cfg.whitelistEnabled);

                // Requirements: external call should succeed.
                if (!success) {
                    if (!cfg.continueOnFailure) {
                        vm.stopBroadcast();
                        return (false, err);
                    }
                    continue;
                }

                (bool readAfterStatusSuccess, bool updatedWhitelistStatus) = _readWhitelistStatus(market);
                // Requirements: post-call state read should succeed.
                if (!readAfterStatusSuccess) {
                    if (!cfg.continueOnFailure) {
                        vm.stopBroadcast();
                        return (false, abi.encodeWithSelector(WhitelistStatusReadFailed.selector));
                    }
                    continue;
                }

                // Requirements: updated whitelist status should equal cfg.whitelistEnabled after the call.
                if (updatedWhitelistStatus != cfg.whitelistEnabled) {
                    if (!cfg.continueOnFailure) {
                        vm.stopBroadcast();
                        return (false, abi.encodeWithSelector(WhitelistStatusMismatch.selector));
                    }
                    continue;
                }
            }

            uint256 usersLength = cfg.users.length;
            for (uint256 j; j < usersLength; ++j) {
                address user = cfg.users[j];

                (bool readUserSuccess, bool currentUserStatus) = _readUserStatus(market, user);
                // Requirements: user status read should succeed.
                if (!readUserSuccess) {
                    if (!cfg.continueOnFailure) {
                        if (broadcastStarted) {
                            vm.stopBroadcast();
                        }
                        return (false, abi.encodeWithSelector(UserWhitelistReadFailed.selector));
                    }
                    continue;
                }

                // Effects + Requirements: short-circuit when requested value is already set; skip mutation when current user
                // status already equals cfg.userStatus.
                if (currentUserStatus == cfg.userStatus) {
                    continue;
                }

                if (!broadcastStarted) {
                    // Interactions: begin broadcast for batched state updates
                    vm.startBroadcast();
                    broadcastStarted = true;
                }

                (success, err) = _setWhitelistedUser(market, user, cfg.userStatus);
                // Requirements: external call should succeed.
                if (!success) {
                    if (!cfg.continueOnFailure) {
                        vm.stopBroadcast();
                        return (false, err);
                    }
                    continue;
                }

                (bool readAfterUserSuccess, bool updatedUserStatus) = _readUserStatus(market, user);
                // Requirements: post-call state read should succeed.
                if (!readAfterUserSuccess) {
                    if (!cfg.continueOnFailure) {
                        vm.stopBroadcast();
                        return (false, abi.encodeWithSelector(UserWhitelistReadFailed.selector));
                    }
                    continue;
                }

                // Requirements: updated user status should equal cfg.userStatus after the call.
                if (updatedUserStatus != cfg.userStatus) {
                    if (!cfg.continueOnFailure) {
                        vm.stopBroadcast();
                        return (false, abi.encodeWithSelector(UserWhitelistMismatch.selector));
                    }
                }
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
        vm.serializeAddress(json, "markets", cfg.markets);
        vm.serializeAddress(json, "users", cfg.users);
        vm.serializeAddress(json, "skipMarkets", cfg.skipMarkets);
        vm.serializeBool(json, "whitelistEnabled", cfg.whitelistEnabled);
        vm.serializeBool(json, "userStatus", cfg.userStatus);
        vm.serializeBool(json, "continueOnFailure", cfg.continueOnFailure);
        vm.serializeUint(json, "marketsCount", cfg.markets.length);
        serialized = vm.serializeUint(json, "usersCount", cfg.users.length);
    }

    /// @notice Updates whitelist enabled status on a gateway
    function _setWhitelistStatus(address market, bool whitelistEnabled)
        internal
        returns (bool success, bytes memory err)
    {
        bytes memory callData;
        if (whitelistEnabled) {
            callData = abi.encodeWithSelector(mTokenGateway.enableWhitelist.selector);
            Logger.logCalldata("mTokenGateway", market, "enableWhitelist", callData);
            return address(market).call(callData);
        }

        callData = abi.encodeWithSelector(mTokenGateway.disableWhitelist.selector);
        Logger.logCalldata("mTokenGateway", market, "disableWhitelist", callData);
        return address(market).call(callData);
    }

    /// @notice Updates user whitelist status on a gateway
    function _setWhitelistedUser(address market, address user, bool userStatus)
        internal
        returns (bool success, bytes memory err)
    {
        bytes memory callData = abi.encodeWithSelector(mTokenGateway.setWhitelistedUser.selector, user, userStatus);
        Logger.logCalldata("mTokenGateway", market, "setWhitelistedUser", callData);
        return address(market).call(callData);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.markets = _readAndLogAddressArray(json, "markets");
        cfg.users = _readAndLogAddressArray(json, "users");
        cfg.skipMarkets = _readAndLogAddressArray(json, "skipMarkets");
        cfg.whitelistEnabled = _readAndLogBool(json, "whitelistEnabled");
        cfg.userStatus = _readAndLogBool(json, "userStatus");
        cfg.continueOnFailure = _readAndLogBool(json, "continueOnFailure");

        // Requirement: cfg.markets.length should be greater than zero.
        require(cfg.markets.length > 0, EmptyMarkets());

        uint256 marketsLength = cfg.markets.length;
        for (uint256 i; i < marketsLength; ++i) {
            // Requirement: cfg.markets[i] should not be the zero address.
            require(cfg.markets[i] != address(0), InvalidMarket(i));
        }

        uint256 usersLength = cfg.users.length;
        for (uint256 i; i < usersLength; ++i) {
            // Requirement: cfg.users[i] should not be the zero address.
            require(cfg.users[i] != address(0), InvalidUser(i));
        }

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readWhitelistStatus(address market) internal view returns (bool success, bool status) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(market).staticcall(abi.encodeWithSignature("whitelistEnabled()"));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, false);
        }

        // Effects: decode returned state value from payload
        status = abi.decode(data, (bool));
        return (true, status);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readUserStatus(address market, address user) internal view returns (bool success, bool status) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(market).staticcall(abi.encodeWithSignature("userWhitelisted(address)", user));

        // Requirements: read call should succeed and return at least 32 bytes.
        if (!callSuccess || data.length < 32) {
            return (false, false);
        }

        // Effects: decode returned state value from payload
        status = abi.decode(data, (bool));
        return (true, status);
    }

    /// @notice Returns true when a market should be skipped
    function _isSkipped(address market, address[] memory skipMarkets) internal pure returns (bool) {
        uint256 length = skipMarkets.length;
        for (uint256 i; i < length; ++i) {
            if (skipMarkets[i] == market) {
                return true;
            }
        }

        return false;
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setWhitelistedUsersOnGateway";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetWhitelistedUsersOnGateway.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetWhitelistedUsersOnGateway.output.json";
    }
}
