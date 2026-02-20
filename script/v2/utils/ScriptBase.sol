// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";

import {DeployerUtil} from "script/v2/utils/DeployerUtil.sol";
import {JsonReader} from "script/v2/utils/JsonReader.sol";
import {Logger} from "script/v2/utils/Logger.sol";

/// @title ScriptBase
/// @author Malda Protocol
/// @notice Base contract for scripts
abstract contract ScriptBase is Script {
    /// @notice The namespace of the script
    string internal namespace;

    /// @notice The path to the config file
    string private configPath;

    /// @notice The path to the output file
    string private outputPath;

    /// @notice The config overrides of the script's config. If a value is present, it will be used instead of the value
    /// in the config file.
    mapping(string name => address value) internal configOverrides;

    constructor() {
        setNamespace(_defaultNamespace());
        setConfigPath(_defaultConfigPath());
        setOutputPath(_defaultOutputPath());
    }

    /// @notice Runs the script
    /// @dev This function is the entry point for the script
    /// @return contractAddress The address of the deployed contract
    function run() public virtual returns (address contractAddress);

    /// @notice Runs the script with a custom config path and output path
    /// @dev This function is the entry point for the script
    /// @param configPath_ The path to the config file
    /// @param outputPath_ The path to the output file
    /// @return contractAddress The address of the deployed contract
    function run(string memory configPath_, string memory outputPath_) public virtual returns (address contractAddress);

    /// @notice Runs the script with a custom namespace, config path and output path
    /// @dev This function is the entry point for the script
    /// @param namespace_ The namespace of the script
    /// @param configPath_ The path to the config file
    /// @param outputPath_ The path to the output file
    /// @return contractAddress The address of the deployed contract
    function run(string memory namespace_, string memory configPath_, string memory outputPath_)
        public
        virtual
        returns (address contractAddress);

    /// @notice Writes the final config to the output file
    /// @param config The config to write to the output file
    function writeFinalConfigToOutput(bytes memory config) public {
        string memory filePath = _getOutputFilePath();
        if (bytes(filePath).length == 0) {
            return;
        }

        vm.writeJson(_serializeConfig(config, namespace), filePath, JsonReader.getPropertyPath(namespace));
    }

    /// @notice Sets the config path
    /// @param configPath_ The path to the config file
    function setConfigPath(string memory configPath_) public {
        configPath = bytes(configPath_).length > 0 ? configPath_ : _defaultConfigPath();
    }

    /// @notice Sets the namespace
    /// @param namespace_ The namespace of the script
    function setNamespace(string memory namespace_) public {
        namespace = bytes(namespace_).length > 0 ? namespace_ : _defaultNamespace();
    }

    /// @notice Sets the output path
    /// @param outputPath_ The path to the output file
    function setOutputPath(string memory outputPath_) public {
        outputPath = bytes(outputPath_).length > 0 ? outputPath_ : _defaultOutputPath();
    }

    /// @notice Sets the config override
    /// @param key The key to update
    /// @param value The value to update the key to
    function setConfigOverride(string memory key, address value) public {
        configOverrides[key] = value;
    }

    /// @notice Serializes the config to be put in the output JSON file
    /// @dev Must be overridden by the child contract
    /// @param config The config to serialize
    /// @param namespace_ The namespace of the script
    /// @return serialized The serialized config
    function _serializeConfig(bytes memory config, string memory namespace_)
        internal
        virtual
        returns (string memory serialized);

    /// @notice Loads and validates the config from the JSON file
    /// @dev Must be overridden by the child contract
    /// @return config The encoded config
    function _loadAndValidateConfig() internal view virtual returns (bytes memory config);

    /// @notice Returns the absolute path to the config file
    /// @return filePath The absolute path to the config file
    function _getConfigFilePath() internal view returns (string memory filePath) {
        filePath = DeployerUtil.buildAbsolutePath(vm, configPath);
    }

    /// @notice Returns the absolute path to the output file
    /// @return filePath The absolute path to the output file
    function _getOutputFilePath() internal view returns (string memory filePath) {
        filePath = DeployerUtil.buildAbsolutePath(vm, outputPath);
    }

    /// @notice Loads the config JSON file
    /// @dev Used by _loadAndValidateConfig to load the config JSON file
    /// @return json The JSON file contents
    function _loadConfigJson() internal view returns (string memory json) {
        json = vm.readFile(_getConfigFilePath());
    }

    /// @notice Reads an address from the config override or the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read an address from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The address read from the JSON file
    function _readAndLogAddress(string memory json, string memory property) internal view returns (address value) {
        if (configOverrides[property] != address(0)) {
            value = configOverrides[property];
        } else {
            value = JsonReader.readAddress(json, JsonReader.getPropertyPath(namespace, property));
        }
        Logger.functionArg(property, value);
    }

    /// @notice Reads a uint256 from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a uint256 from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The uint256 read from the JSON file
    function _readAndLogUint(string memory json, string memory property) internal view returns (uint256 value) {
        value = JsonReader.readUint(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads a string from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a string from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The string read from the JSON file
    function _readAndLogString(string memory json, string memory property) internal view returns (string memory value) {
        value = JsonReader.readString(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads bytes from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read bytes from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bytes read from the JSON file
    function _readAndLogBytes(string memory json, string memory property) internal view returns (bytes memory value) {
        value = JsonReader.readBytes(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bytes32 from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a bytes32 from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bytes32 read from the JSON file
    function _readAndLogBytes32(string memory json, string memory property) internal view returns (bytes32 value) {
        value = JsonReader.readBytes32(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bool from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a bool from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bool read from the JSON file
    function _readAndLogBool(string memory json, string memory property) internal view returns (bool value) {
        value = JsonReader.readBool(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Returns the namespace of the script. Hardcoded by each script.
    /// @return namespace The namespace of the script
    function _defaultNamespace() internal pure virtual returns (string memory);

    /// @notice Returns the path to the config file. Hardcoded by each script.
    /// @return path The path to the config file
    function _defaultConfigPath() internal pure virtual returns (string memory path);

    /// @notice Returns the path to the output file. Hardcoded by each script.
    /// @return path The path to the output file
    function _defaultOutputPath() internal pure virtual returns (string memory path);
}
