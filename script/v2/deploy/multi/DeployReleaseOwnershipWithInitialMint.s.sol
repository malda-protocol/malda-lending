// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DeployReleaseOwnership} from "script/v2/deploy/multi/DeployReleaseOwnership.s.sol";
import {DeployerUtil} from "script/utils/DeployerUtil.sol";
import {JsonReader} from "script/utils/JsonReader.sol";

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

/// @title DeployReleaseOwnershipWithInitialMint
/// @notice Extends ownership handoff flow with explicit, gated initial mint execution
contract DeployReleaseOwnershipWithInitialMint is DeployReleaseOwnership {
    ////////////////////////////////////////////////////////////
    //                        Structs                         //
    ////////////////////////////////////////////////////////////

    struct InitialMintConfig {
        bool enableInitialMint;
        address initialMintReceiver;
        uint256 initialMintAmount;
        uint256[] initialMintHostMarketIndices;
    }

    ////////////////////////////////////////////////////////////
    //                       Constants                        //
    ////////////////////////////////////////////////////////////

    string internal constant NS_INITIAL_MINT = "initialMint";

    ////////////////////////////////////////////////////////////
    //                         Errors                         //
    ////////////////////////////////////////////////////////////

    error InitialMintDisabled();
    error InvalidInitialMintConfig();
    error InvalidInitialMintMarketIndex(uint256 index, uint256 marketsLength);
    error MintBurnTransferFailed(address market);

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Executes ownership transfer + optional initial mint using default config/output paths
    /// @return success Always true when execution completes
    function run() public override returns (bool success) {
        return run(DEFAULT_CONFIG_PATH, DEFAULT_OUTPUT_PATH);
    }

    /// @notice Executes ownership transfer + optional initial mint using custom config/output paths
    /// @param configPath_ Shared config path
    /// @param outputPath_ Shared output path
    /// @return success Always true when execution completes
    function run(string memory configPath_, string memory outputPath_) public override returns (bool success) {
        // Interactions: execute ownership handoff first, then optional initial mint
        _runOwnershipTransfer(configPath_, outputPath_);
        _runOptionalInitialMint(configPath_, outputPath_);
        return true;
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Executes optional initial mint flow guarded by `enableInitialMint`
    /// @param configPath_ Shared config path
    /// @param outputPath_ Shared output path
    function _runOptionalInitialMint(string memory configPath_, string memory outputPath_) internal {
        // Effects: select config and output files for this invocation
        setConfigPath(vm, configPath_);
        setOutputPath(vm, outputPath_);

        // Interactions: load initial mint config and grouped output snapshot
        string memory configJson = vm.readFile(DeployerUtil.buildAbsolutePath(vm, configPath));
        string memory outputJson = vm.readFile(DeployerUtil.buildAbsolutePath(vm, outputPath));
        InitialMintConfig memory cfg = _loadInitialMintConfig(configJson);

        // Requirements: initial mint must be explicitly enabled and fully configured
        require(cfg.enableInitialMint, InitialMintDisabled());
        require(
            cfg.initialMintReceiver != address(0) && cfg.initialMintAmount > 0
                && cfg.initialMintHostMarketIndices.length > 0,
            InvalidInitialMintConfig()
        );

        // Effects: resolve host markets from grouped output
        address[] memory hostMarkets = _readAggregatedAddressArray(outputJson, "hostMarkets");
        require(hostMarkets.length > 0, InvalidInitialMintConfig());

        // Interactions: execute mint + burn workflow on selected host markets
        vm.startBroadcast();
        for (uint256 i; i < cfg.initialMintHostMarketIndices.length; ++i) {
            // Requirements: each selected index should be within host market bounds
            uint256 marketIndex = cfg.initialMintHostMarketIndices[i];
            require(marketIndex < hostMarkets.length, InvalidInitialMintMarketIndex(marketIndex, hostMarkets.length));

            mErc20Host market = mErc20Host(payable(hostMarkets[marketIndex]));
            IERC20(market.underlying()).approve(address(market), cfg.initialMintAmount);
            market.mint(cfg.initialMintAmount, cfg.initialMintReceiver, 0);

            bool success = IERC20(address(market)).transfer(address(0), market.balanceOf(cfg.initialMintReceiver));
            require(success, MintBurnTransferFailed(address(market)));
        }
        vm.stopBroadcast();
    }

    ////////////////////////////////////////////////////////////
    //                    View / Pure Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Loads initial mint config from shared config JSON
    /// @param configJson Shared config JSON blob
    /// @return cfg Parsed initial mint config
    function _loadInitialMintConfig(string memory configJson) internal view returns (InitialMintConfig memory cfg) {
        // Effects: decode initial mint parameters
        cfg.enableInitialMint =
            JsonReader.readBool(configJson, JsonReader.getPropertyPath(NS_INITIAL_MINT, "enableInitialMint"));
        cfg.initialMintReceiver =
            JsonReader.readAddress(configJson, JsonReader.getPropertyPath(NS_INITIAL_MINT, "initialMintReceiver"));
        cfg.initialMintAmount =
            JsonReader.readUint(configJson, JsonReader.getPropertyPath(NS_INITIAL_MINT, "initialMintAmount"));
        cfg.initialMintHostMarketIndices = JsonReader.readUintArray(
            configJson, JsonReader.getPropertyPath(NS_INITIAL_MINT, "initialMintHostMarketIndices")
        );
    }
}
