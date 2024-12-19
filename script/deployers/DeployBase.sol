// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

import {Deployer} from "src/utils/Deployer.sol";

import {Script} from "forge-std/Script.sol";

contract DeployBase is Script {
    Deployer deployer;

    function setUp() public virtual {
        deployer = Deployer(payable(vm.envAddress("DEPLOYER_ADDRESS")));
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
