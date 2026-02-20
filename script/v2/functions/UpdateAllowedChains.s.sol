// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

// solhint-disable avoid-low-level-calls

import {FunctionCallScriptBase} from "script/v2/utils/FunctionCallScriptBase.sol";
import {ScriptBase} from "script/v2/utils/ScriptBase.sol";

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

/// @title UpdateAllowedChains
/// @notice Function-call script that updates allowed chain status on host market
contract UpdateAllowedChains is FunctionCallScriptBase {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct DeployConfig {
        /// @notice The address of the market
        address market;
        /// @notice The chain id to update
        uint32 chainId;
        /// @notice The target allowed status for the chain id
        bool isAllowed;
    }
    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    /// @notice Error thrown when the market is invalid
    error InvalidMarket();
    /// @notice Error thrown when the chain id is invalid
    error InvalidChainId();
    /// @notice Error thrown when allowed chain read fails
    error AllowedChainReadFailed();
    /// @notice Error thrown when allowed chain mismatch occurs
    error AllowedChainMismatch(bool expected, bool actual);

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

        (bool readBeforeSuccess, bool currentAllowed) = _readAllowedChain(cfg.market, cfg.chainId);
        // Requirements: pre-call state read must succeed
        if (!readBeforeSuccess) {
            return (false, abi.encodeWithSelector(AllowedChainReadFailed.selector));
        }

        // Effects: short-circuit when requested value is already set
        if (currentAllowed == cfg.isAllowed) {
            return (true, bytes(""));
        }
        // Interactions: perform target call as active broadcaster
        vm.broadcast();
        (success, err) = address(cfg.market)
            .call(abi.encodeWithSelector(mErc20Host.updateAllowedChain.selector, cfg.chainId, cfg.isAllowed));
        if (!success) {
            return (false, err);
        }

        (bool readAfterSuccess, bool updatedAllowed) = _readAllowedChain(cfg.market, cfg.chainId);
        // Requirements: post-call state read must succeed
        if (!readAfterSuccess) {
            return (false, abi.encodeWithSelector(AllowedChainReadFailed.selector));
        }

        // Requirements: resulting onchain state must match requested value
        if (updatedAllowed != cfg.isAllowed) {
            return (false, abi.encodeWithSelector(AllowedChainMismatch.selector, cfg.isAllowed, updatedAllowed));
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
        vm.serializeUint(json, "chainId", cfg.chainId);
        serialized = vm.serializeBool(json, "isAllowed", cfg.isAllowed);
    }

    /// @inheritdoc ScriptBase
    function _loadAndValidateConfig() internal view override returns (bytes memory deployConfig) {
        // Interactions: load config JSON from configured path
        string memory json = _loadConfigJson();

        DeployConfig memory cfg;
        uint256 chainIdRaw;

        cfg.market = _readAndLogAddress(json, "market");
        chainIdRaw = _readAndLogUint(json, "chainId");
        cfg.isAllowed = _readAndLogBool(json, "isAllowed");

        require(cfg.market != address(0), InvalidMarket());
        require(chainIdRaw < 2 ** 32, InvalidChainId());

        cfg.chainId = uint32(chainIdRaw);

        deployConfig = abi.encode(cfg);
    }

    /// @notice Internal helper to read current onchain state for post-call assertions
    function _readAllowedChain(address market, uint32 chainId) internal view returns (bool success, bool isAllowed) {
        // Interactions: query target contract state with staticcall
        (bool callSuccess, bytes memory data) =
            address(market).staticcall(abi.encodeWithSignature("allowedChains(uint32)", chainId));

        // Requirements: staticcall must return the expected payload
        if (!callSuccess || data.length < 32) {
            return (false, false);
        }

        // Effects: decode returned state value from payload
        isAllowed = abi.decode(data, (bool));
        return (true, isAllowed);
    }

    /// @inheritdoc ScriptBase
    function _defaultNamespace() internal pure override returns (string memory) {
        return "updateAllowedChains";
    }

    /// @inheritdoc ScriptBase
    function _defaultConfigPath() internal pure override returns (string memory path) {
        path = "config/functions/UpdateAllowedChains.config.json";
    }

    /// @inheritdoc ScriptBase
    function _defaultOutputPath() internal pure override returns (string memory path) {
        path = "config/functions/UpdateAllowedChains.output.json";
    }
}
