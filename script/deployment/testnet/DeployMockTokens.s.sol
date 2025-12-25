// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

/**
 * @title DeployMockTokens
 * @notice Deploys USDCMock and wstETHMock tokens for testnet deployment
 * @dev Run this script before deploying the core protocol
 *
 * Usage:
 * forge script script/deployment/testnet/DeployMockTokens.s.sol:DeployMockTokens \
 *     --rpc-url linea_sepolia \
 *     --verify \
 *     --broadcast
 */
contract DeployMockTokens is Script {
    struct TokenConfig {
        string name;
        string symbol;
        uint8 decimals;
        uint256 mintLimit;
    }

    // POH Verifier address on Linea Sepolia
    address public constant POH_VERIFY = 0xBf14cFAFD7B83f6de881ae6dc10796ddD7220831;

    // Default mint limits (can be updated later via setMintLimit)
    uint256 public constant USDC_LIMIT = 1_000_000 * 1e6; // 1M USDC
    uint256 public constant WSTETH_LIMIT = 1_000 * 1e18; // 1000 wstETH

    /// @notice Deploys USDCMock and wstETHMock tokens for testnet deployment
    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerKey);

        console.log("\n=== Deploying Mock Tokens ===");
        console.log("Deployer/Owner:", owner);
        console.log("Network: Linea Sepolia");
        console.log("");

        // Deploy USDC Mock
        TokenConfig memory usdcConfig =
            TokenConfig({name: "USDC Mock", symbol: "USDC-M", decimals: 6, mintLimit: USDC_LIMIT});

        address usdcMock = deployToken(usdcConfig, owner, deployerKey);

        // Deploy wstETH Mock
        TokenConfig memory wstethConfig =
            TokenConfig({name: "wstETH Mock", symbol: "wstETH-M", decimals: 18, mintLimit: WSTETH_LIMIT});

        address wstethMock = deployToken(wstethConfig, owner, deployerKey);

        // Print summary
        console.log("\n=== Deployment Summary ===");
        console.log("USDC Mock deployed at:", usdcMock);
        console.log("  - Name:", usdcConfig.name);
        console.log("  - Symbol:", usdcConfig.symbol);
        console.log("  - Decimals:", usdcConfig.decimals);
        console.log("  - Mint Limit:", usdcConfig.mintLimit);
        console.log("");
        console.log("wstETH Mock deployed at:", wstethMock);
        console.log("  - Name:", wstethConfig.name);
        console.log("  - Symbol:", wstethConfig.symbol);
        console.log("  - Decimals:", wstethConfig.decimals);
        console.log("  - Mint Limit:", wstethConfig.mintLimit);
        console.log("");
        console.log("=== Next Steps ===");
        console.log("1. Update deployment-config-testnet.json with these addresses:");
        console.log("   - USDCMock: %s", usdcMock);
        console.log("   - wstETHMock: %s", wstethMock);
        console.log("2. Run: forge script script/deployment/testnet/UpdateConfigWithTokens.s.sol");
        console.log("   (This will automatically update the config file)");
    }

    function deployToken(TokenConfig memory config, address owner, uint256 deployerKey) internal returns (address) {
        console.log("Deploying %s...", config.name);

        vm.startBroadcast(deployerKey);

        ERC20Mock token =
            new ERC20Mock(config.name, config.symbol, config.decimals, owner, POH_VERIFY, config.mintLimit);

        vm.stopBroadcast();

        console.log("  %s deployed at: %s", config.symbol, address(token));

        return address(token);
    }
}

