// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";
import {DeployerUtil} from "script/utils/DeployerUtil.sol";
import {JsonReader} from "script/utils/JsonReader.sol";
import {Logger} from "script/utils/Logger.sol";

abstract contract ScriptBase is Script {
    ///////////////////////////////////////////////////////////
    //                        Storage                        //
    ///////////////////////////////////////////////////////////

    /// @notice The config namespace of the script
    string internal namespace;

    /// @notice Relative path to the config JSON file
    string private configPath;

    /// @notice Relative path to the output JSON file
    string private outputPath;

    /// @notice The config overrides of the script's config. If a value is present, it will be used instead of the value
    /// in the config file.
    mapping(string name => address value) internal configOverrides;

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    constructor() {
        // Effects: set the default namespace
        setNamespace(_defaultNamespace());

        // Effects: set the default config path
        setConfigPath(_defaultConfigPath());

        // Effects: set the default output path
        setOutputPath(_defaultOutputPath());
    }

    ////////////////////////////////////////////////////////////
    //              External / Public Functions               //
    ////////////////////////////////////////////////////////////

    /// @notice Runs the script
    /// @dev Base function whose steps is common to all scripts. All child contracts must override invidual steps.
    /// @return contractAddress The address of the deployed contract
    function run() public virtual returns (address contractAddress);

    /// @notice Runs the script with a custom config path and output path
    /// @dev Used to run the script with a custom config path and output path
    /// @param configPath_ The path to the config JSON file
    /// @param outputPath_ The path to the output JSON file
    /// @return contractAddress The address of the deployed contract
    function run(string memory configPath_, string memory outputPath_) public virtual returns (address contractAddress);

    /// @notice Runs the deployment script with a custom config path and namespace
    /// @dev Used to run the deployment script with a custom config path and namespace
    /// @param namespace_ The namespace of the script
    /// @param configPath_ The path to the config JSON file
    /// @param outputPath_ The path to the output JSON file
    /// @return contractAddress The address of the deployed contract
    function run(string memory namespace_, string memory configPath_, string memory outputPath_)
        public
        virtual
        returns (address contractAddress);

    /// @notice Writes the final config to the output JSON file
    /// @param config The config to write to the output JSON file
    function writeFinalConfigToOutput(bytes memory config) public {
        // 1. Absolute path to this script's output file
        string memory filePath = _getOutputFilePath();

        // 2. Load entire current file JSON into an in-memory object ("root" serves as a placeholder "key" for the root
        // JSON object, although it is not used)
        string memory rootKey = "root";
        string memory json = vm.serializeJson(rootKey, vm.readFile(filePath));

        // 3. Upsert the final config object
        json = vm.serializeString(rootKey, namespace, _serializeConfig(config, namespace));

        // 4. Overwrite the file with the new root
        vm.writeJson(json, filePath);
    }

    /// @notice Sets the config path
    /// @param configPath_ The path to the config JSON file
    function setConfigPath(string memory configPath_) public {
        // Effects: set the config path, if provided, oth erwise use the default config path
        configPath = bytes(configPath_).length > 0 ? configPath_ : _defaultConfigPath();
    }

    /// @notice Sets the namespace
    /// @param namespace_ The namespace of the script
    function setNamespace(string memory namespace_) public {
        // Effects: set the namespace, if provided, otherwise use the default namespace
        namespace = bytes(namespace_).length > 0 ? namespace_ : _defaultNamespace();
    }

    /// @notice Sets the output path
    /// @param outputPath_ The path to the output JSON file
    function setOutputPath(string memory outputPath_) public {
        // Effects: set the output path, if provided, otherwise use the default output path
        outputPath = bytes(outputPath_).length > 0 ? outputPath_ : _defaultOutputPath();
    }

    /// @notice Sets the config override
    /// @param key The key to update
    /// @param value The value to update the key to
    function setConfigOverride(string memory key, address value) public {
        // Effects: set the config override
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

    /// @notice Returns the absolute path to the output JSON file
    /// @return filePath The absolute path to the output JSON file
    function _getOutputFilePath() internal view returns (string memory filePath) {
        filePath = DeployerUtil.buildAbsolutePath(vm, outputPath);
    }

    /// @notice Loads the config JSON file
    /// @dev Used by _loadAndValidateConfig to load the config JSON file
    /// @return json The JSON file contents
    function _loadConfigJson() internal view returns (string memory json) {
        json = vm.readFile(DeployerUtil.buildAbsolutePath(vm, configPath));
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

    /// @notice Reads a uint256 from JSON and logs it
    /// @param json Raw JSON string
    /// @param property  Property key (without step prefix)
    /// @return value The uint256 read from the JSON file
    function _readAndLogUint(string memory json, string memory property) internal view returns (uint256 value) {
        value = JsonReader.readUint(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads a string value from the JSON and logs it
    /// @param json Raw JSON string
    /// @param property  Property key (without step prefix)
    /// @return value The string read from the JSON file
    function _readAndLogString(string memory json, string memory property) internal view returns (string memory value) {
        value = JsonReader.readString(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bytes value from the JSON and logs it
    /// @param json Raw JSON string
    /// @param property Property key (without step prefix)
    function _readAndLogBytes(string memory json, string memory property) internal view returns (bytes memory value) {
        value = JsonReader.readBytes(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bytes32 value from the JSON and logs it
    /// @param json Raw JSON string
    /// @param property  Property key (without step prefix)
    /// @return value The bytes32 read from the JSON file
    function _readAndLogBytes32(string memory json, string memory property) internal view returns (bytes32 value) {
        value = JsonReader.readBytes32(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Reads a bool value from the JSON and logs it
    /// @param json Raw JSON string
    /// @param property Property key (without step prefix)
    /// @return value The bool read from the JSON file
    function _readAndLogBool(string memory json, string memory property) internal view returns (bool value) {
        value = JsonReader.readBool(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    /// @notice Returns the namespace of the script. Hardcoded by each script.
    /// @dev Must be overridden by the child contract. In deployment scripts, this is the name of the contract being
    /// deployed. In function call scripts, this is the name of the function being called.
    /// @return namespace The namespace of the script
    function _defaultNamespace() internal pure virtual returns (string memory);

    /// @notice Returns the path to the config JSON file
    /// @dev Must be overridden by the child contract
    /// @return path The path to the config JSON file
    function _defaultConfigPath() internal pure virtual returns (string memory path);

    /// @notice Returns the path to the output JSON file
    /// @dev Must be overridden by the child contract
    /// @return path The path to the output JSON file
    function _defaultOutputPath() internal pure virtual returns (string memory path);
}
