// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {Logger} from "script/utils/Logger.sol";

abstract contract ConfigSetup {
    ////////////////////////////////////////////////////////////
    //                       Immutables                       //
    ////////////////////////////////////////////////////////////

    /// @notice The default config path
    string private _defaultConfigPath;

    /// @notice The default output path
    string private _defaultOutputPath;

    ////////////////////////////////////////////////////////////
    //                        Storage                         //
    ////////////////////////////////////////////////////////////

    /// @notice The actual config path
    string internal configPath;

    /// @notice The actual output path
    string internal outputPath;

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    /// @notice Constructor
    /// @param defaultConfigPath The default config path
    /// @param defaultOutputPath The default output path
    constructor(string memory defaultConfigPath, string memory defaultOutputPath) {
        _defaultConfigPath = defaultConfigPath;
        _defaultOutputPath = defaultOutputPath;
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

    /// @notice Sets the config path
    /// @param vm The VM instance
    /// @param configPath_ The config path
    function setConfigPath(Vm vm, string memory configPath_) internal {
        // Effects: set the config path
        if (bytes(configPath_).length == 0) {
            Logger.noConfigPath();
            configPath = _defaultConfigPath;
        } else {
            configPath = configPath_;
        }

        // Log the config path
        Logger.logConfigPath(vm, configPath);
    }

    /// @notice Sets the output path
    /// @param vm The VM instance
    /// @param outputPath_ The output path
    function setOutputPath(Vm vm, string memory outputPath_) internal {
        // Effects: set the output path
        if (bytes(outputPath_).length == 0) {
            Logger.noOutputPath();
            outputPath = _defaultOutputPath;
        } else {
            outputPath = outputPath_;
        }

        // Log the output path
        Logger.logOutputPath(vm, outputPath, true);
    }
}
