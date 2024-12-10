// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {Script, console} from "forge-std/Script.sol";
import {BaseMarketDeploy} from "script/deployment/markets/BaseMarketDeploy.s.sol";

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
contract DeployHostMarket is BaseMarketDeploy {
    struct MarketData {
        address underlyingToken;
        address operator;
        address interestModel;
        uint256 exchaneRateMantissa;
        string name;
        string symbol;
        uint8 decimals;
        address zkVerifier;
        address roles;
    }

    function run(MarketData memory data) public returns (address) {
        address deployedLogs = _deployLogs(data.roles, data.underlyingToken, "mErc20Host");

        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        bytes32 salt = getSalt(string.concat(data.name, "mErc20Host", string(abi.encodePacked(data.underlyingToken))));
        address created = deployer.create(
            salt, abi.encodePacked(type(mErc20Host).creationCode, _getConstructorData(data, deployedLogs))
        );

        console.log(" Host market deployed at: %s", created);
        vm.stopBroadcast();

        return created;
    }

    function _getConstructorData(MarketData memory data, address deployedLogs) private view returns (bytes memory) {
        address owner = vm.envAddress("OWNER");
        return abi.encode(
            data.underlyingToken,
            data.operator,
            data.interestModel,
            data.exchaneRateMantissa,
            data.name,
            data.symbol,
            data.decimals,
            owner,
            data.zkVerifier,
            deployedLogs
        );
    }
}
