// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

import {console} from "forge-std/Script.sol";
import {DeployBase} from "./DeployBase.sol";
import {LendingProtocolMock} from "test/mocks/LendingProtocolMock.sol";

contract LendingProtocolMockScript is DeployBase {
    LendingProtocolMock lendingProtocolMock;

    function run(address token, address owner) public {
        uint256 key = vm.envUint("PRIVATE_KEY");

        bytes32 salt = keccak256(abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT"))));

        vm.startBroadcast(key);

        address deployedAddress =
            _deployCreate2(salt, type(LendingProtocolMock).creationCode, abi.encode(token, address(0), owner));
        console.log("LendingProtocolMock contract deployed at: %s", deployedAddress);

        vm.stopBroadcast();
    }
}
