// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {mTokenLogs} from "src/mToken/mTokenLogs.sol";
import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";

abstract contract BaseMarketDeploy is Script, DeployBase {
    function _deployLogs(address roles, address underlyingAddress, string memory name) internal returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt(string.concat(name, "mTokenLogs", string(abi.encodePacked(underlyingAddress))));
        address created = deployer.create(salt, abi.encodePacked(type(mTokenLogs).creationCode, abi.encode(roles)));

        console.log(" mToken logs deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
