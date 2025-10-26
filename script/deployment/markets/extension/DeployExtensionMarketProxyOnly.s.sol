// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployExtensionMarketProxyOnly is Script {
    function run() public returns (address) {

        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        address blacklister = 0x46fF12FA621Df323a0C4e529d580e91222a5ad70;
        address owner = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
        address zkVerifier = 0x24Fa38dadA9e772Bf3474C4d3d190c326744Be32;
        address roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;

        address underlyingToken = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
        address implementation = 0xb72E6D190D0CBEC01B792a6b48F06e70Ff469c4C;
        string memory name = "mWBTC";

     
        // Deploy proxy
        bytes32 proxySalt = getSalt(string.concat(name, "V1.0.5"));

        console.log("salt");
        console.logBytes32(proxySalt);

        // Precompute deterministic proxy address
        address proxy = deployer.precompute(proxySalt);

        // Initialization data for the proxy
        bytes memory initData = abi.encodeWithSelector(
            mTokenGateway.initialize.selector,
            payable(owner),
            underlyingToken,
            roles,
            blacklister,
            zkVerifier
        );

        // Calldata for the multisig to call Deployer.create(...)
        bytes memory data = abi.encodeWithSelector(
            Deployer.create.selector,
            proxySalt,
            abi.encodePacked(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(implementation, owner, initData)
            )
        );

        console.log("\n=== Multisig Transaction Details ===");
        console.log("To (Deployer):");
        console.logAddress(address(deployer));

        console.log("\nPredicted Proxy Address:");
        console.logAddress(proxy);

        console.log("\nCalldata for multisig:");
        console.logBytes(data);

        return proxy;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1.0.5")))
        );
    }

    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
