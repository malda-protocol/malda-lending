// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {stdJson} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

library JsonReader {
    using stdJson for string;

    Vm private constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

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

    function readAddressArray(string memory json, string memory path) internal view returns (address[] memory value) {
        value = json.readAddressArrayOr(path, new address[](0));
    }

    function readUint(string memory json, string memory path) internal view returns (uint256 value) {
        value = json.readUintOr(path, 0);
    }

    function readString(string memory json, string memory path) internal view returns (string memory value) {
        value = json.readStringOr(path, "");
    }

    function readBytes(string memory json, string memory path) internal view returns (bytes memory value) {
        value = json.readBytesOr(path, "");
    }

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

    function readBool(string memory json, string memory path) internal view returns (bool value) {
        value = json.readBoolOr(path, false);
    }

    function getPropertyPath(string memory property) internal pure returns (string memory path) {
        if (bytes(property).length > 0) {
            path = string.concat(".", property);
        }
    }

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
