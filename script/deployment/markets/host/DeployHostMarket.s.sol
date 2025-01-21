// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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
        address zkVerifier;
        address roles;
    }

    function run(
        Deployer deployer,
        MarketData memory data
    ) public returns (address) {
        uint256 key = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        // Deploy implementation
        bytes32 implSalt = getSalt(string.concat("mErc20HostImplementation", data.name));
        address implementation = deployer.create(
            implSalt,
            type(mErc20Host).creationCode
        );
        console.log("Implementation deployed at:", implementation);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            data.underlyingToken,
            data.operator,
            data.interestModel,
            data.exchangeRateMantissa,
            data.name,
            data.symbol,
            data.decimals,
            owner,
            data.zkVerifier
        );

        // Deploy proxy
        bytes32 proxySalt = getSalt(string.concat("mErc20HostProxy", data.name));
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

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
