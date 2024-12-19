// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.19;

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
    address constant OPERATOR = 0x6a39C1B89a25a8fA399fF73766417ED2213d5dEe;

    // address constant USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff; // Linea
    // address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum
    // address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Ethereum
    // address constant USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // Optimism
    // address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Base
    // address constant USDC = 0xFEce4462D57bD51A6A552365A011b95f0E16d9B7; // Linea Sepolia
    address constant USDC = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7; // Optimism Sepolia

    function run() public returns (address) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);

        address owner = vm.envAddress("OWNER");

        bytes32 salt = getSalt("GovernanceRoundDepositContract");
        address created = deployer.create(salt, abi.encodePacked(type(GovernanceRound).creationCode, abi.encode(USDC, owner, OPERATOR)));

        console.log(" GovernanceRound deployed at: %s", created);

        vm.stopBroadcast();

        return created;
    }
}
