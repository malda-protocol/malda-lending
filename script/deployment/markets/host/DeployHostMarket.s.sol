// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * forge script DeployHostMarket  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run((address,address,address,uint256,string,string,uint8,address,address,address))" "(0xD718826bBC28e61dC93aaCaE04711c8e755B4915,0x421f6ff3691e2c9d6e0447e0fc0157ef578f92c6,0x62def138a240b86dd44048b9e7dcc01b6391e638,20000000000000000,'Name','Sym',18,0x62def138a240b86dd44048b9e7dcc01b6391e638,0xb0fe2cdded33f9331e5ecd1c35640846a4fb9058,0x5cc15473f5bd753a09b81c7bc3d8dcea50eb0f9a)"  \
 *     --broadcast
 */
contract DeployHostMarket is Script {
    struct MarketData {
        address underlyingToken;
        address operator;
        address interestModel;
        uint256 exchangeRateMantissa;
        string name;
        string symbol;
        uint8 decimals;
        address owner;
        address zkVerifier;
        address roles;
    }

    function run(Deployer deployer, MarketData memory marketData) public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");

        // Deploy implementation
        bytes32 implSalt = getSalt("mTokenHost-implementation");

        address implementation = deployer.precompute(implSalt);

        console.log("Deploying mErc20Host implementation");

        // Check if implementation already exists
        if (implementation.code.length > 0) {
            console.log("Implementation already exists at ", implementation);
        } else {
            vm.startBroadcast(key);
            deployer.create(implSalt, type(mErc20Host).creationCode);
            vm.stopBroadcast();

            console.log("Host implementation deployed at:", implementation);
        }

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            marketData.underlyingToken,
            marketData.operator,
            marketData.interestModel,
            marketData.exchangeRateMantissa,
            marketData.name,
            marketData.symbol,
            marketData.decimals,
            marketData.owner,
            marketData.zkVerifier,
            marketData.roles
        );

        // Deploy proxy
        bytes32 proxySalt = getSalt(marketData.name);

        vm.startBroadcast(key);
        address proxy = deployer.create(
            proxySalt,
            abi.encodePacked(
                type(TransparentUpgradeableProxy).creationCode, abi.encode(implementation, marketData.owner, initData)
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
