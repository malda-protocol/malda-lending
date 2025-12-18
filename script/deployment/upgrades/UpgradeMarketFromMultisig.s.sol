// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "forge-std/console2.sol";

contract UpgradeMarketFromMultisig is Script {
    // Market type enum to determine which implementation to deploy
    enum MarketType {
        HOST,
        GATEWAY
    }

    // Admin slot from ERC1967
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() public {
        // Setup

        /**
        MarketType marketType = MarketType.GATEWAY;
        string memory salt = "ReleaseV1.0.5-patch-firewallliquidation0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b";
        address create3Deployer = 0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df;

        uint256 key = vm.envUint("PRIVATE_KEY");
        Deployer deployer = Deployer(payable(create3Deployer));
        // Get ProxyAdmin address from proxy
        address proxyAdmin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
        console.log("ProxyAdmin address:", proxyAdmin);

        // Deploy new implementation
        address newImpl;
        if (marketType == MarketType.HOST) {
            newImpl = _deployHostImplementation(deployer, salt);
        } else {
            newImpl = _deployGatewayImplementation(deployer, salt);
        }   

        /// ^ deploy implementation above

        return; 
        */
        /// > set new implementation below

        address proxy = 0xa31963C753f277f7d82d98F56b2C374256925eB7;
        address newImpl = address(0);
        address proxyAdmin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
        console.log("ProxyAdmin address:", proxyAdmin);

        // ------------------------------------------------------------
        // Prepare Safe transaction for ProxyAdmin.upgradeAndCall
        // ------------------------------------------------------------

        bytes memory data = abi.encodeWithSelector(
            ProxyAdmin.upgradeAndCall.selector,
            ITransparentUpgradeableProxy(payable(proxy)),
            newImpl,
            bytes("")                               // no initializer
        );

        console2.log("========================================");
        console2.log("Submit the following in your Safe:");
        console2.log("To (ProxyAdmin):", proxyAdmin);
        console2.log("Value: 0");
        console2.logBytes(data);
        console2.log("========================================");

        console2.log(
            "This will upgrade proxy %s to new implementation %s",
            proxy,
            newImpl
        );
    }

    function _deployHostImplementation(Deployer deployer, string memory salt) internal returns (address) {
        bytes32 implSalt = keccak256(abi.encodePacked("mErc20HostImplementation", salt));

        bytes memory creationCode = type(mErc20Host).creationCode;
        bytes memory data = abi.encodeWithSelector(
            deployer.create.selector,
            implSalt,
            creationCode
        );

        console2.log("========================================");
        console2.log("Submit the following in your Safe:");
        console2.log("To (Deployer):", address(deployer));
        console2.log("Value: 0");
        console2.logBytes(data);
        console2.log("========================================");

        try deployer.precompute(implSalt) returns (address predicted) {
            console2.log("Predicted implementation address:", predicted);
            return predicted;
        } catch {
            console2.log("Cannot predict address (no predict fn on deployer)");
            return address(0);
        }
    }

    function _deployGatewayImplementation(Deployer deployer, string memory salt) internal returns (address) {
        bytes32 implSalt = keccak256(abi.encodePacked("mTokenGatewayImplementation", salt));

        bytes memory creationCode = type(mTokenGateway).creationCode;
        bytes memory data = abi.encodeWithSelector(
            deployer.create.selector,
            implSalt,
            creationCode
        );

        console2.log("========================================");
        console2.log("Submit the following in your Safe:");
        console2.log("To (Deployer):", address(deployer));
        console2.log("Value: 0");
        console2.logBytes(data);
        console2.log("========================================");

        try deployer.precompute(implSalt) returns (address predicted) {
            console2.log("Predicted implementation address:", predicted);
            return predicted;
        } catch {
            console2.log("Cannot predict address (no predict fn on deployer)");
            return address(0);
        }
    }
}