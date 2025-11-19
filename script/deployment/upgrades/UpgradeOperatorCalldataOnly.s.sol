// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {Operator} from "src/Operator/Operator.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract UpgradeOperatorCalldataOnly is Script {
    // ERC1967 admin slot
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() public {
        // ---- config ----
        address proxy = 0x4bbd2B599425026b8A504816D8A043636e2D7Ec7;
        string memory salt = "ReleaseV1.0.5-patch-firewallUpdate";
        address create3Deployer = 0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df;

        Deployer deployer = Deployer(payable(create3Deployer));
        address proxyAdmin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));

        console.log("ProxyAdmin:", proxyAdmin);

        // 1) Print Safe calldata to deploy implementation via Deployer
        address predictedImpl = 0x7A1641d397Da85BC146eA722F99381726f9bfA10; // _planOperatorImplementation(deployer, salt);

        console.log("predictedImpl:", predictedImpl);

        // 2) If we can predict the impl address, also print the ProxyAdmin calldata
        if (predictedImpl != address(0)) {
            bytes memory dataUpgradeAndCall = abi.encodeWithSelector(
                ProxyAdmin.upgradeAndCall.selector,
                ITransparentUpgradeableProxy(payable(proxy)),
                predictedImpl,
                bytes("") // no init call
            );

            console2.log("========================================");
            console2.log("Submit the following in your Safe (UPGRADE VIA ProxyAdmin):");
            console2.log("To (ProxyAdmin):", proxyAdmin);
            console2.log("Value: 0");
            console2.log("Data (upgradeAndCall):");
            console2.logBytes(dataUpgradeAndCall);
           
        } else {
            console2.log("Predicted implementation unavailable. After deployment, re-run to print upgrade calldata.");
        }
    }

    /// @notice Plans (does not execute) the Operator implementation deployment.
    /// Prints Safe calldata for `Deployer.create(implSalt, creationCode)` and returns predicted address if available.
    function _planOperatorImplementation(
        Deployer deployer,
        string memory salt
    ) internal returns (address) {
        bytes32 implSalt = keccak256(abi.encodePacked("Operator", salt));
        bytes memory creationCode = type(Operator).creationCode;

        // calldata to call the Deployer contract (no broadcast, just print)
        bytes memory data = abi.encodeWithSelector(
            deployer.create.selector,
            implSalt,
            creationCode
        );

        console2.log("========================================");
        console2.log("Submit the following in your Safe (DEPLOY IMPLEMENTATION):");
        console2.log("To (Deployer):", address(deployer));
        console2.log("Value: 0");
        console2.log("Data:");
        console2.logBytes(data);
        console2.log("========================================");

        // try to show predicted impl address (if Deployer supports it)
        try deployer.precompute(implSalt) returns (address predicted) {
            console2.log("Predicted implementation address:", predicted);
            return predicted;
        } catch {
            console2.log("Cannot predict address (no precompute on Deployer)");
            return address(0);
        }
    }
}
