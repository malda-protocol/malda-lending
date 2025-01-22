// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "../../deployers/DeployBase.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeMarkets is DeployBase {
    using stdJson for string;

    function run() public override {
        super.setUp();

        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Upgrading markets on %s ===", network);

            // Deploy new implementations
            address newImpl;
            if (configs[network].isHost) {
                newImpl = _deployHostImplementation();
            } else {
                newImpl = _deployGatewayImplementation();
            }

            // Upgrade each market
            for (uint256 j = 0; j < configs[network].markets.length; j++) {
                address marketAddress = _getMarketAddress(configs[network].markets[j].underlying);
                _upgradeMarket(marketAddress, newImpl);
            }
        }
    }

    function _deployHostImplementation() internal returns (address) {
        vm.startBroadcast(key);
        address implementation = address(new mErc20Host());
        vm.stopBroadcast();
        console.log("New mErc20Host implementation deployed at:", implementation);
        return implementation;
    }

    function _deployGatewayImplementation() internal returns (address) {
        vm.startBroadcast(key);
        address implementation = address(new mTokenGateway());
        vm.stopBroadcast();
        console.log("New mTokenGateway implementation deployed at:", implementation);
        return implementation;
    }

    function _upgradeMarket(address proxy, address newImplementation) internal {
        vm.startBroadcast(key);
        ERC1967Proxy(payable(proxy)).upgradeTo(newImplementation);
        vm.stopBroadcast();
        console.log("Upgraded market %s to implementation %s", proxy, newImplementation);
    }

    function _getMarketAddress(address underlying) internal view returns (address) {
        // You'll need to implement this based on how you store market addresses
        // Options:
        // 1. Read from a deployment artifacts file
        // 2. Pass as script parameters
        // 3. Read from a registry contract
        revert("Implement market address lookup");
    }
} 