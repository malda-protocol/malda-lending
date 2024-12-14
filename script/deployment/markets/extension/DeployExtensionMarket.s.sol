// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {Script, console} from "forge-std/Script.sol";
import {BaseMarketDeploy} from "script/deployment/markets/BaseMarketDeploy.s.sol";

/**
 * forge script DeployExtensionMarket  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run(address,address,address,address)" 0x0,0x0,0x0,0x0 \
 *     --broadcast
 */
contract DeployExtensionMarket is BaseMarketDeploy {
    function run(address underlyingToken, address roles, address zkVerifier, address imageRegistry)
        public
        returns (address)
    {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt(string.concat("mTokenGateway", string(abi.encodePacked(underlyingToken))));
        address created = deployer.create(
            salt,
            abi.encodePacked(
                type(mTokenGateway).creationCode, abi.encode(owner, underlyingToken, roles, zkVerifier, imageRegistry)
            )
        );

        console.log(" Extension market deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
