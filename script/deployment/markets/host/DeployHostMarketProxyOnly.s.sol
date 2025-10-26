// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mErc20Immutable} from "src/mToken/mErc20Immutable.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * forge script DeployHostMarketProxyOnly  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --sig "run((address,address,address,uint256,string,string,uint8,address,address,address))" "(0xD718826bBC28e61dC93aaCaE04711c8e755B4915,0x421f6ff3691e2c9d6e0447e0fc0157ef578f92c6,0x62def138a240b86dd44048b9e7dcc01b6391e638,20000000000000000,'Name','Sym',18,0x62def138a240b86dd44048b9e7dcc01b6391e638,0xb0fe2cdded33f9331e5ecd1c35640846a4fb9058,0x5cc15473f5bd753a09b81c7bc3d8dcea50eb0f9a)"  \
 *     --broadcast
 */
contract DeployHostMarketProxyOnly is Script {
    function run() public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");

        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        address underlyingToken = 0x3aAB2285ddcDdaD8edf438C1bAB47e1a9D05a9b4;
        address operator = 0x4bbd2B599425026b8A504816D8A043636e2D7Ec7;
        address interestModel = 0x1D10B8fE03D467D3F1F5147507BFbCA66ccCd2Af;
        uint256 exchangeRateMantissa = uint256(2e16);
        string memory name = "mWBTC";
        string memory symbol = "mWBTC";
        uint8 decimals = 8;
        address owner = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
        address zkVerifier = 0x24Fa38dadA9e772Bf3474C4d3d190c326744Be32;
        address roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
        address implementation = 0x982A1E86BC8C450eFEc302Ea1A283352e6E0d129;

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            underlyingToken,
            operator,
            interestModel,
            exchangeRateMantissa,
            name,
            symbol,
            decimals,
            owner,
            zkVerifier,
            roles
        );

        bytes memory data = abi.encodeWithSelector(
            Deployer.create.selector,
            0x394480ae1a257a0b768332109310515e249b53ca2fe2cf06d694ba911034a3b6,
            abi.encodePacked(
                type(TransparentUpgradeableProxy).creationCode,
                abi.encode(implementation, owner, initData)
            )
        );


        console.log("\n=== Multisig Transaction Details ===");
        console.log("To (Deployer):");
        console.logAddress(address(deployer));

        console.log("\nPredicted Proxy Address:");
        console.logAddress(deployer.precompute(0x394480ae1a257a0b768332109310515e249b53ca2fe2cf06d694ba911034a3b6));

        console.log("\nCalldata for multisig:");
        console.logBytes(data);

        return address(0);
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
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
