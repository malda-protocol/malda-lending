// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {Script, console} from "forge-std/Script.sol";
import {BaseMarketDeploy} from "script/deployment/markets/BaseMarketDeploy.s.sol";
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
contract DeployExtensionMarket is BaseMarketDeploy {
    struct GatewayData {
        address underlyingToken;
        address roles;
        address zkVerifier;
    }

    function run(GatewayData memory data) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        // Deploy implementation
        bytes32 implSalt = getSalt(string.concat(
            "mTokenGatewayImplementation", 
            string(abi.encodePacked(data.underlyingToken))
        ));
        address implementation = vm.envOr(
            "MTOKEN_GATEWAY_IMPLEMENTATION",
            deployer.create(implSalt, type(mTokenGateway).creationCode)
        );
        console.log("Implementation deployed at:", implementation);

        // Prepare initialization data
        bytes memory initData = _getInitializationData(data);

        // Deploy proxy
        bytes32 proxySalt = getSalt(string.concat(
            "mTokenGatewayProxy", 
            string(abi.encodePacked(data.underlyingToken))
        ));
        address proxy = deployer.create(
            proxySalt,
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(implementation, initData)
            )
        );

        console.log("Proxy deployed at:", proxy);
        vm.stopBroadcast();

        return proxy;
    }

    function _getInitializationData(GatewayData memory data) private view returns (bytes memory) {
        address owner = vm.envAddress("OWNER");
        return abi.encodeWithSelector(
            mTokenGateway.initialize.selector,
            payable(owner),
            data.underlyingToken,
            data.roles,
            data.zkVerifier
        );
    }
}
