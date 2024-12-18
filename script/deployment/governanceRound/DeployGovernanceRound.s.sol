// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {DeployBase} from "script/deployers/DeployBase.sol";
import {GovernanceRound} from "src/governanceRound/governanceRound.sol";

/**
 * forge script DeployGovernanceRound  \
 *     --slow \
 *     --verify \
 *     --verifier-url <url> \
 *     --rpc-url <url> \
 *     --etherscan-api-key <key> \
 *     --broadcast
 */
contract DeployGovernanceRound is Script, DeployBase {

    // TODO: Set operator
    address constant OPERATOR = 0x0000000000000000000000000000000000000000;

    address constant USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff; // Linea
    // address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum
    // address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Ethereum
    // address constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // Optimism
    // address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base


    function run() public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("GovernanceRound");
        address created = deployer.create(salt, abi.encodePacked(type(GovernanceRound).creationCode, abi.encode(USDC, owner, OPERATOR)));

        console.log(" GovernanceRound deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
