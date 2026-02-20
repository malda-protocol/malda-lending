// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";

import {DeployerUtil} from "script/v2/utils/DeployerUtil.sol";
import {JsonReader} from "script/v2/utils/JsonReader.sol";
import {Logger} from "script/v2/utils/Logger.sol";

/// @title ScriptBase
/// @author Malda Protocol
/// @notice Base contract for script entrypoints, config decoding, and output serialization
abstract contract ScriptBase is Script {
    ////////////////////////////////////////////////////////////
    //                        Storage                         //
    ////////////////////////////////////////////////////////////

    /// @notice The namespace of the script
    string internal namespace;

    /// @notice The path to the config file
    string private configPath;

    /// @notice The path to the output file
    string private outputPath;

    /// @notice Config overrides by field name
    /// @dev When a key has a non-zero value, it overrides JSON config for that property
    mapping(string name => address value) internal configOverrides;

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    constructor() {
        setNamespace(_defaultNamespace());
        setConfigPath(_defaultConfigPath());
        setOutputPath(_defaultOutputPath());
    }

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

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
        // Interactions: resolve output path from configured relative or absolute path
        string memory filePath = _getOutputFilePath();

        // Requirements: skip when output path is intentionally empty
        if (bytes(filePath).length == 0) {
            return;
        }

        // Effects: serialize resolved config under namespace in output json
        vm.writeJson(_serializeConfig(config, namespace), filePath, JsonReader.getPropertyPath(namespace));
    }

    /// @notice Sets the config path
    /// @param configPath_ The path to the config file
    function setConfigPath(string memory configPath_) public {
        // Effects: use provided path or fallback to script default
        configPath = bytes(configPath_).length > 0 ? configPath_ : _defaultConfigPath();
    }

    /// @notice Sets the namespace
    /// @param namespace_ The namespace of the script
    function setNamespace(string memory namespace_) public {
        // Effects: use provided namespace or fallback to script default
        namespace = bytes(namespace_).length > 0 ? namespace_ : _defaultNamespace();
    }

    /// @notice Sets the output path
    /// @param outputPath_ The path to the output file
    function setOutputPath(string memory outputPath_) public {
        // Effects: use provided path or fallback to script default
        outputPath = bytes(outputPath_).length > 0 ? outputPath_ : _defaultOutputPath();
    }

    /// @notice Sets the config override
    /// @param key The key to update
    /// @param value The value to update the key to
    function setConfigOverride(string memory key, address value) public {
        // Effects: override a single address-valued config property
        configOverrides[key] = value;
    }

    ////////////////////////////////////////////////////////////
    //              Internal / Private Functions              //
    ////////////////////////////////////////////////////////////

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
        // Effects: resolve config path against project root when needed
        filePath = DeployerUtil.buildAbsolutePath(vm, configPath);
    }

    /// @notice Returns the absolute path to the output file
    /// @return filePath The absolute path to the output file
    function _getOutputFilePath() internal view returns (string memory filePath) {
        // Effects: resolve output path against project root when needed
        filePath = DeployerUtil.buildAbsolutePath(vm, outputPath);
    }

    /// @notice Loads the config JSON file
    /// @dev Used by _loadAndValidateConfig to load the config JSON file
    /// @return json The JSON file contents
    function _loadConfigJson() internal view returns (string memory json) {
        // Interactions: read config file contents using resolved config path
        json = vm.readFile(_getConfigFilePath());
    }

    /// @notice Reads an address from the config override or the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read an address from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The address read from the JSON file
    function _readAndLogAddress(string memory json, string memory property) internal view returns (address value) {
        // Effects: prefer non-zero override, otherwise read from namespaced json
        if (configOverrides[property] != address(0)) {
            value = configOverrides[property];
        } else {
            value = JsonReader.readAddress(json, JsonReader.getPropertyPath(namespace, property));
        }

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a uint256 from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a uint256 from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The uint256 read from the JSON file
    function _readAndLogUint(string memory json, string memory property) internal view returns (uint256 value) {
        // Effects: read uint256 from namespaced json path
        value = JsonReader.readUint(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a string from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a string from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The string read from the JSON file
    function _readAndLogString(string memory json, string memory property) internal view returns (string memory value) {
        // Effects: read string from namespaced json path
        value = JsonReader.readString(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads bytes from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read bytes from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bytes read from the JSON file
    function _readAndLogBytes(string memory json, string memory property) internal view returns (bytes memory value) {
        // Effects: read bytes from namespaced json path
        value = JsonReader.readBytes(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bytes32 from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a bytes32 from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bytes32 read from the JSON file
    function _readAndLogBytes32(string memory json, string memory property) internal view returns (bytes32 value) {
        // Effects: read bytes32 from namespaced json path
        value = JsonReader.readBytes32(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bool from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a bool from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bool read from the JSON file
    function _readAndLogBool(string memory json, string memory property) internal view returns (bool value) {
        // Effects: read bool from namespaced json path
        value = JsonReader.readBool(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads an address array from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read an address array from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The address array read from the JSON file
    function _readAndLogAddressArray(string memory json, string memory property)
        internal
        view
        returns (address[] memory value)
    {
        // Effects: read address array from namespaced json path
        value = JsonReader.readAddressArray(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a uint256 array from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a uint256 array from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The uint256 array read from the JSON file
    function _readAndLogUintArray(string memory json, string memory property)
        internal
        view
        returns (uint256[] memory value)
    {
        // Effects: read uint256 array from namespaced json path
        value = JsonReader.readUintArray(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a string array from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a string array from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The string array read from the JSON file
    function _readAndLogStringArray(string memory json, string memory property)
        internal
        view
        returns (string[] memory value)
    {
        // Effects: read string array from namespaced json path
        value = JsonReader.readStringArray(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bool array from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a bool array from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bool array read from the JSON file
    function _readAndLogBoolArray(string memory json, string memory property)
        internal
        view
        returns (bool[] memory value)
    {
        // Effects: read bool array from namespaced json path
        value = JsonReader.readBoolArray(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bytes32 array from the JSON file and logs it
    /// @dev Used by _loadAndValidateConfig to read a bytes32 array from the JSON file and log it
    /// @param json The JSON file contents
    /// @param property The property to read from the JSON file
    /// @return value The bytes32 array read from the JSON file
    function _readAndLogBytes32Array(string memory json, string memory property)
        internal
        view
        returns (bytes32[] memory value)
    {
        // Effects: read bytes32 array from namespaced json path
        value = JsonReader.readBytes32Array(json, JsonReader.getPropertyPath(namespace, property));

        // Log: emit argument trace for script observability
        Logger.functionArg(property, value);
    }

    /// @notice Returns the namespace of the script. Hardcoded by each script
    /// @return namespace The namespace of the script
    function _defaultNamespace() internal pure virtual returns (string memory);

    /// @notice Returns the path to the config file. Hardcoded by each script
    /// @return path The path to the config file
    function _defaultConfigPath() internal pure virtual returns (string memory path);

    /// @notice Returns the path to the output file. Hardcoded by each script
    /// @return path The path to the output file
    function _defaultOutputPath() internal pure virtual returns (string memory path);
}
