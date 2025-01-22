// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeMarket is Script {
    // Market type enum to determine which implementation to deploy
    enum MarketType { HOST, GATEWAY }

    function run(
        address create3Deployer,
        address proxy,
        MarketType marketType,
        string memory salt // Optional: for deterministic deployment
    ) public {
        // Setup
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        Deployer deployer = Deployer(payable(create3Deployer));

        // Deploy new implementation
        address newImpl;
        if (marketType == MarketType.HOST) {
            newImpl = _deployHostImplementation(deployer, salt);
        } else {
            newImpl = _deployGatewayImplementation(deployer, salt);
        }

        // Upgrade proxy
        vm.startBroadcast(key);
        ERC1967Proxy(payable(proxy)).upgradeTo(newImpl);
        vm.stopBroadcast();

        console.log("Upgraded market %s to implementation %s", proxy, newImpl);
    }

    function _deployHostImplementation(Deployer deployer, string memory salt) internal returns (address) {
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        
        bytes32 implSalt = keccak256(abi.encodePacked(
            "mErc20HostImplementation",
            salt
        ));
        
        address implementation = deployer.create(
            implSalt,
            type(mErc20Host).creationCode
        );
        
        vm.stopBroadcast();
        console.log("New mErc20Host implementation deployed at:", implementation);
        return implementation;
    }

    function _deployGatewayImplementation(Deployer deployer, string memory salt) internal returns (address) {
        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));
        
        bytes32 implSalt = keccak256(abi.encodePacked(
            "mTokenGatewayImplementation",
            salt
        ));
        
        address implementation = deployer.create(
            implSalt,
            type(mTokenGateway).creationCode
        );
        
        vm.stopBroadcast();
        console.log("New mTokenGateway implementation deployed at:", implementation);
        return implementation;
    }
} 