// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

import {Script} from "forge-std/Script.sol";

abstract contract DeployBase is Script {
    function _computeCreate2Address(bytes32 salt, bytes memory bytecode) public view returns (address) {
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 _data = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash));

        return address(uint160(uint256(_data)));
    }

    function _deployCreate2(bytes32 salt, bytes memory bytecode, bytes memory constructorArgs)
        public
        returns (address)
    {
        bytes memory bytecodeWithConstructor = abi.encodePacked(bytecode, constructorArgs);

        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(bytecodeWithConstructor, 0x20), mload(bytecodeWithConstructor), salt)

            if iszero(deployedAddress) { revert(0, 0) }
        }

        return deployedAddress;
    }
}
