// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

library JsonReader {
    using stdJson for string;

    // Get VM instance for parsing
    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    ////////////////////////////////////////////////////////////
    //                   Value Reader Utils                   //
    ////////////////////////////////////////////////////////////

    /// @notice Reads an address from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the property
    /// @return value The address read from the JSON file
    function readAddress(string memory json, string memory path) internal view returns (address value) {
        // Read the address from the JSON file using path
        string memory valueRaw = json.readStringOr(path, "");

        // If the value is empty, return zero address
        if (bytes(valueRaw).length == 0) {
            value = address(0);
        } else {
            // If the value is not empty, try to parse it as an address
            try VM.parseAddress(valueRaw) returns (address val) {
                value = val;
            } catch {
                value = address(0);
            }
        }
    }

    /// @notice Reads an address array from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the property
    /// @return value The address array read from the JSON file
    function readAddressArray(string memory json, string memory path) internal view returns (address[] memory value) {
        // Read the address array from the JSON file using path
        value = json.readAddressArrayOr(path, new address[](0));
    }

    /// @notice Reads a uint256 from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the property
    /// @return value The uint256 read from the JSON file
    function readUint(string memory json, string memory path) internal view returns (uint256 value) {
        // Read the uint256 from the JSON file using path
        value = json.readUintOr(path, 0);
    }

    /// @notice Reads a string from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the property
    /// @return value The string read from the JSON file
    function readString(string memory json, string memory path) internal view returns (string memory value) {
        // Read the string from the JSON file using path
        value = json.readStringOr(path, "");
    }

    /// @notice Reads a bytes from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the property
    /// @return value The bytes read from the JSON file
    function readBytes(string memory json, string memory path) internal view returns (bytes memory value) {
        // Read the bytes from the JSON file using path
        value = json.readBytesOr(path, "");
    }

    /// @notice Reads a bytes32 from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the property
    /// @return value The bytes32 read from the JSON file
    function readBytes32(string memory json, string memory path) internal view returns (bytes32 value) {
        // Read the address from the JSON file using path
        string memory valueRaw = json.readStringOr(path, "");

        // If the value is empty, return zero address
        if (bytes(valueRaw).length == 0) {
            value = bytes32(0);
        } else {
            // If the value is not empty, try to parse it as a bytes32
            try VM.parseBytes32(valueRaw) returns (bytes32 val) {
                value = val;
            } catch {
                value = bytes32(bytes(valueRaw));
            }
        }
    }

    /// @notice Reads a bool from the JSON file
    /// @param json The JSON file contents
    /// @param path The path to the property
    /// @return value The bool read from the JSON file
    function readBool(string memory json, string memory path) internal view returns (bool value) {
        // Read the bool from the JSON file using path
        value = json.readBoolOr(path, false);
    }

    ////////////////////////////////////////////////////////////
    //                       Path Utils                       //
    ////////////////////////////////////////////////////////////

    /// @notice Builds the path to the property stored in a JSON config file
    /// @param property The property to read from the JSON file
    /// @return path The path to the property
    function getPropertyPath(string memory property) internal pure returns (string memory path) {
        if (bytes(property).length > 0) {
            path = string.concat(".", property);
        }
    }

    /// @notice Builds the path to the property stored in a JSON config file
    /// @param parentProperty The name of the parent property
    /// @param property The property to read from the JSON file
    /// @return path The path to the property
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

    /// @notice Builds the path to the property stored in a JSON config file
    /// @param grandparentProperty The name of the grandparent property
    /// @param parentProperty The name of the parent property
    /// @param property The property to read from the JSON file
    /// @return path The path to the property
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
