// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {FunctionCallScriptBase} from "script/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/utils/ScriptBase.sol";
import {Logger} from "script/utils/Logger.sol";

/// @title SetWhitelistDisabled
/// @notice Function-call script that disables whitelist on gateway markets
contract SetWhitelistDisabled is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The list of market addresses
        address[] markets;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when markets array is empty
    error EmptyMarkets();
    /// @notice Error thrown when the market is invalid
    error InvalidMarket(uint256 index);
    /// @notice Error thrown when whitelist status read fails
    error WhitelistStatusReadFailed(address market);
    /// @notice Error thrown when whitelist status mismatch occurs
    error WhitelistStatusMismatch(address market, bool expected, bool actual);

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

            (bool readBeforeSuccess, bool whitelistEnabledBefore) = _readWhitelistStatus(market);
            // Requirements: pre-call state read should succeed.
            if (!readBeforeSuccess) {
                if (broadcastStarted) {
                    vm.stopBroadcast();
                }
                return (false, abi.encodeWithSelector(WhitelistStatusReadFailed.selector, market));
            }

            if (!whitelistEnabledBefore) {
                continue;
            }

            if (!broadcastStarted) {
                // Interactions: begin broadcast for batched state updates
                vm.startBroadcast();
                broadcastStarted = true;
            }

            bytes memory callData = abi.encodeWithSignature("disableWhitelist()");
            Logger.logCalldata("mTokenGateway", market, "disableWhitelist", callData);
            (success, err) = address(market).call(callData);
            // Requirements: external call should succeed.
            if (!success) {
                vm.stopBroadcast();
                return (false, err);
            }

            (bool readAfterSuccess, bool whitelistEnabledAfter) = _readWhitelistStatus(market);
            // Requirements: post-call state read should succeed.
            if (!readAfterSuccess) {
                vm.stopBroadcast();
                return (false, abi.encodeWithSelector(WhitelistStatusReadFailed.selector, market));
            }

            if (whitelistEnabledAfter) {
                vm.stopBroadcast();
                return
                    (
                        false,
                        abi.encodeWithSelector(WhitelistStatusMismatch.selector, market, false, whitelistEnabledAfter)
                    );
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
        serialized = vm.serializeUint(json, "marketsCount", cfg.markets.length);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        cfg.markets = _readAndLogAddressArray(json, "markets");

        // Requirement: cfg.markets.length should be greater than zero.
        require(cfg.markets.length > 0, EmptyMarkets());

        uint256 marketsLength = cfg.markets.length;
        for (uint256 i; i < marketsLength; ++i) {
            // Requirement: cfg.markets[i] should not be the zero address.
            require(cfg.markets[i] != address(0), InvalidMarket(i));
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

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "setWhitelistDisabled";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/SetWhitelistDisabled.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/SetWhitelistDisabled.output.json";
    }
}
