// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * forge script DeployExtensionMarket  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run((address,address,address))" "(0x0,0x0,0x0)" \
 *     --broadcast
 */
contract DeployExtensionMarket is Script {
    function run(
        Deployer deployer,
        address underlyingToken,
        string calldata name,
        address owner,
        address zkVerifier,
        address roles
    ) public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        // Deploy implementation
        bytes32 implSalt = getSalt("mTokenGateway-implementation");

        address implementation = deployer.precompute(implSalt);

        // Check if implementation already exists
        if (implementation.code.length > 0) {
            console.log("Implementation already exists at ", implementation);
        } else {
            vm.startBroadcast(key);
            deployer.create(implSalt, type(mTokenGateway).creationCode);
            vm.stopBroadcast();

            console.log("Extension implementation deployed at:", implementation);
        }

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            mTokenGateway.initialize.selector, payable(owner), underlyingToken, roles, zkVerifier
        );

        // Deploy proxy
        bytes32 proxySalt = getSalt(name);

        vm.startBroadcast(key);
        address proxy = deployer.create(
            proxySalt,
            abi.encodePacked(
                type(TransparentUpgradeableProxy).creationCode, abi.encode(implementation, owner, initData)
            )
        );
        vm.stopBroadcast();

        console.log("Market deployed at:", proxy);

        return proxy;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
