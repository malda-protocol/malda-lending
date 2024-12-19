// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script script/deployers/Deployer.s.sol:DeployerScript \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployerScript is Script {
    Deployer deployer;

    function run() public {
        uint256 key = vm.envUint("PRIVATE_KEY");

        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOYER_SALT"))));

        vm.startBroadcast(key);

        address deployedAddress = _deployCreate2(salt, type(Deployer).creationCode, "");
        console.log("Deployer contract deployed at: %s", deployedAddress);

        vm.stopBroadcast();
    }

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
