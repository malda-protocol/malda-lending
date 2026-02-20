// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

/// @title JsonReader
/// @author Malda Protocol
/// @notice Library for reading JSON data
library JsonReader {
    using stdJson for string;

    /// @notice The VM instance
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Reads an address from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the address
    /// @return value The address read from the JSON file
    function readAddress(string memory json, string memory path) internal view returns (address value) {
        string memory valueRaw = json.readStringOr(path, "");
        if (bytes(valueRaw).length == 0) {
            return address(0);
        }

        try VM.parseAddress(valueRaw) returns (address parsed) {
            return parsed;
        } catch {
            return address(0);
        }
    }

    /// @notice Reads an address array from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the address array
    /// @return value The address array read from the JSON file
    function readAddressArray(string memory json, string memory path) internal view returns (address[] memory value) {
        value = json.readAddressArrayOr(path, new address[](0));
    }

    /// @notice Reads a uint256 from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the uint256
    /// @return value The uint256 read from the JSON file
    function readUint(string memory json, string memory path) internal view returns (uint256 value) {
        value = json.readUintOr(path, 0);
    }

    /// @notice Reads a string from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the string
    /// @return value The string read from the JSON file
    function readString(string memory json, string memory path) internal view returns (string memory value) {
        value = json.readStringOr(path, "");
    }

    /// @notice Reads bytes from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the bytes
    /// @return value The bytes read from the JSON file
    function readBytes(string memory json, string memory path) internal view returns (bytes memory value) {
        value = json.readBytesOr(path, "");
    }

    /// @notice Reads a bytes32 from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the bytes32
    /// @return value The bytes32 read from the JSON file
    function readBytes32(string memory json, string memory path) internal view returns (bytes32 value) {
        string memory valueRaw = json.readStringOr(path, "");
        if (bytes(valueRaw).length == 0) {
            return bytes32(0);
        }

        try VM.parseBytes32(valueRaw) returns (bytes32 parsed) {
            return parsed;
        } catch {
            return bytes32(bytes(valueRaw));
        }
    }

    /// @notice Reads a bool from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the bool
    /// @return value The bool read from the JSON file
    function readBool(string memory json, string memory path) internal view returns (bool value) {
        value = json.readBoolOr(path, false);
    }

    /// @notice Gets the property path
    /// @param property The property
    /// @return path The property path
    function getPropertyPath(string memory property) internal pure returns (string memory path) {
        if (bytes(property).length > 0) {
            path = string.concat(".", property);
        }
    }

    /// @notice Gets the property path
    /// @param parentProperty The parent property
    /// @param property The property
    /// @return path The property path
    function getPropertyPath(string memory parentProperty, string memory property)
        internal
        pure
        returns (string memory path)
    {
        path = getPropertyPath(property);
        if (bytes(parentProperty).length > 0) {
            path = string.concat(getPropertyPath(parentProperty), path);
        }
    }

    /// @notice Gets the property path
    /// @param grandparentProperty The grandparent property
    /// @param parentProperty The parent property
    /// @param property The property
    /// @return path The property path
    function getPropertyPath(string memory grandparentProperty, string memory parentProperty, string memory property)
        internal
        pure
        returns (string memory path)
    {
        path = getPropertyPath(parentProperty, property);
        if (bytes(grandparentProperty).length > 0) {
            path = string.concat(getPropertyPath(grandparentProperty), path);
        }
    }
}
