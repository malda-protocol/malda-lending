// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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
    struct GatewayData {
        address underlyingToken;
        address roles;
        address zkVerifier;
    }

    function run(Deployer deployer, GatewayData memory data) public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        // Deploy implementation
        bytes32 implSalt =
            getSalt(string.concat("mTokenGatewayImplementation", string(abi.encodePacked(data.underlyingToken))));
        address implementation = deployer.create(implSalt, type(mTokenGateway).creationCode);
        console.log("Implementation deployed at:", implementation);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            mTokenGateway.initialize.selector, payable(owner), data.underlyingToken, data.roles, data.zkVerifier
        );

        // Deploy proxy
        bytes32 proxySalt = getSalt(string.concat("mTokenGatewayProxy", string(abi.encodePacked(data.underlyingToken))));
        address proxy = deployer.create(
            proxySalt, abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initData))
        );

        console.log("Proxy deployed at:", proxy);
        vm.stopBroadcast();
        return proxy;
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
