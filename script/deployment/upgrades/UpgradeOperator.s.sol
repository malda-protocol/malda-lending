// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {Operator} from "src/Operator/Operator.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract UpgradeOperator is Script {
    // Admin slot from ERC1967
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() public {
        // Setup

        address proxy = 0x4bbd2B599425026b8A504816D8A043636e2D7Ec7;
        string memory salt = "ReleaseV1.0.5-patch-minBorrowSize";
        address create3Deployer = 0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df;

        uint256 key = vm.envUint("PRIVATE_KEY");
        Deployer deployer = Deployer(payable(create3Deployer));
        // Get ProxyAdmin address from proxy
        address proxyAdmin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
        console.log("ProxyAdmin address:", proxyAdmin);

        // Deploy new implementation
        address newImpl = _deployImplementation(deployer, salt);

        // Upgrade proxy through ProxyAdmin
        vm.startBroadcast(key);
        ProxyAdmin(proxyAdmin).upgradeAndCall(ITransparentUpgradeableProxy(payable(proxy)), newImpl, "");
        vm.stopBroadcast();

        console.log("Upgraded operator %s to implementation %s", proxy, newImpl);
    }

    function _deployImplementation(Deployer deployer, string memory salt) internal returns (address) {
        bytes32 implSalt = keccak256(abi.encodePacked("Operator", salt));
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address implementation = deployer.create(implSalt, type(Operator).creationCode);
        vm.stopBroadcast();

        console.log("New Operator implementation deployed at:", implementation);
        return implementation;
    }
}
