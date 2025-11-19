// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {Deployer} from "src/utils/Deployer.sol";

/**
 * forge script DeployRebalancer  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --sig "run(address)" 0x0 \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployRebalancerWithConfig is Script {
    function run() public {
    //function run(address roles, address saveAddress, address admin, Deployer deployer, bytes memory initData) public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        bytes32 salt = getSalt("RebalancerV1.0.5");

        address roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
        address saveAddress = 0xB819A871d20913839c37f316Dc914b0570bfc0eE;
        Deployer deployer = Deployer(payable(0x8F91616F05b3D74A8Ae56e43C585F0972Ccb91Df));
        address admin = 0xB819A871d20913839c37f316Dc914b0570bfc0eE; 
        bytes memory initData = "";

        
        address[] memory markets = new address[](3);
        markets[0] = 0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b;
        markets[1] = 0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99;
        markets[2] = 0x66DfCBf23319D68bdF0cB57797Fcc0A64d2265f8;
        address[] memory bridges = new address[](2);
        bridges[0] = 0xB77358f17b588a20Dc8A0529b7d5658eA7328c33;
        bridges[1] = 0x0D6C5079CdCdC7d84104F0598EBFAd943dc5281e;
        uint32[] memory destinations = new uint32[](3);
        destinations[0] = 1;
        destinations[1] = 59144;
        destinations[2] = 8453;
        address[] memory tokens = new address[](3);
        tokens[0] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        tokens[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        tokens[2] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;


        Rebalancer.BridgeTokens[] memory bridgeTokens = new Rebalancer.BridgeTokens[](2);
        bridgeTokens[0] = Rebalancer.BridgeTokens({
            bridge: 0xB77358f17b588a20Dc8A0529b7d5658eA7328c33,
            tokens: tokens
        });
        bridgeTokens[1] = Rebalancer.BridgeTokens({
            bridge: 0x0D6C5079CdCdC7d84104F0598EBFAd943dc5281e,
            tokens: tokens
        });

        
        Rebalancer.InitInfo memory infoStr = Rebalancer.InitInfo(bridgeTokens, markets, bridges, destinations);
        initData = abi.encode(infoStr);

        address created = deployer.precompute(salt);

        bytes memory creationCode = abi.encodePacked(
            type(Rebalancer).creationCode,
            abi.encode(roles, saveAddress, admin, initData)
        );
        console.log("========================================");
        console.log("Submit the following in your Safe (DEPLOY Rebalancer via Deployer):");
        console.log("To (Deployer):", address(deployer));
        console.log("Value: 0");
        console.log("Salt:");
        console.logBytes32(salt);
        console.log("Data (Deployer.create):");
        console.logBytes(abi.encodeWithSelector(
            deployer.create.selector,
            salt,
            creationCode
        ));
        console.log("========================================");
    }

    function getSalt(string memory name) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(msg.sender, bytes(vm.envString("DEPLOY_SALT")), bytes(string.concat(name, "-v1")))
        );
    }
}
