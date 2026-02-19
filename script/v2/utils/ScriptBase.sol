// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script} from "forge-std/Script.sol";

import {DeployerUtil} from "script/v2/utils/DeployerUtil.sol";
import {JsonReader} from "script/v2/utils/JsonReader.sol";
import {Logger} from "script/v2/utils/Logger.sol";

abstract contract ScriptBase is Script {
    string internal namespace;

    string private configPath;

    string private outputPath;

    mapping(string name => address value) internal configOverrides;

    constructor() {
        setNamespace(_defaultNamespace());
        setConfigPath(_defaultConfigPath());
        setOutputPath(_defaultOutputPath());
    }

    function run() public virtual returns (address contractAddress);

    function run(string memory configPath_, string memory outputPath_) public virtual returns (address contractAddress);

    function run(string memory namespace_, string memory configPath_, string memory outputPath_)
        public
        virtual
        returns (address contractAddress);

    function writeFinalConfigToOutput(bytes memory config) public {
        string memory filePath = _getOutputFilePath();
        if (bytes(filePath).length == 0) {
            return;
        }

        vm.writeJson(_serializeConfig(config, namespace), filePath, JsonReader.getPropertyPath(namespace));
    }

    function setConfigPath(string memory configPath_) public {
        configPath = bytes(configPath_).length > 0 ? configPath_ : _defaultConfigPath();
    }

    function setNamespace(string memory namespace_) public {
        namespace = bytes(namespace_).length > 0 ? namespace_ : _defaultNamespace();
    }

    function setOutputPath(string memory outputPath_) public {
        outputPath = bytes(outputPath_).length > 0 ? outputPath_ : _defaultOutputPath();
    }

    function setConfigOverride(string memory key, address value) public {
        configOverrides[key] = value;
    }

    function _serializeConfig(bytes memory config, string memory namespace_)
        internal
        virtual
        returns (string memory serialized);

    function _loadAndValidateConfig() internal view virtual returns (bytes memory config);

    function _getConfigFilePath() internal view returns (string memory filePath) {
        filePath = DeployerUtil.buildAbsolutePath(vm, configPath);
    }

    function _getOutputFilePath() internal view returns (string memory filePath) {
        filePath = DeployerUtil.buildAbsolutePath(vm, outputPath);
    }

    function _loadConfigJson() internal view returns (string memory json) {
        json = vm.readFile(_getConfigFilePath());
    }

    function _readAndLogAddress(string memory json, string memory property) internal view returns (address value) {
        if (configOverrides[property] != address(0)) {
            value = configOverrides[property];
        } else {
            value = JsonReader.readAddress(json, JsonReader.getPropertyPath(namespace, property));
        }
        Logger.functionArg(property, value);
    }

    function _readAndLogUint(string memory json, string memory property) internal view returns (uint256 value) {
        value = JsonReader.readUint(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    function _readAndLogString(string memory json, string memory property) internal view returns (string memory value) {
        value = JsonReader.readString(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    function _readAndLogBytes(string memory json, string memory property) internal view returns (bytes memory value) {
        value = JsonReader.readBytes(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    function _readAndLogBytes32(string memory json, string memory property) internal view returns (bytes32 value) {
        value = JsonReader.readBytes32(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    function _readAndLogBool(string memory json, string memory property) internal view returns (bool value) {
        value = JsonReader.readBool(json, JsonReader.getPropertyPath(namespace, property));
        Logger.functionArg(property, value);
    }

    function _defaultNamespace() internal pure virtual returns (string memory);

    function _defaultConfigPath() internal pure virtual returns (string memory path);

    function _defaultOutputPath() internal pure virtual returns (string memory path);
}
