// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {console} from "forge-std/Script.sol";
import {Deployer} from "src/utils/Deployer.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {DeployBaseRelease} from "../../deployers/DeployBaseRelease.sol";

/**
 * @title DeployMockTokens
 * @notice Deploys USDCMock and wstETHMock tokens for testnet deployment
 * @dev Run this script before deploying the core protocol
 *
 * Usage:
 * forge script script/deployment/testnet/DeployMockTokens.s.sol:DeployMockTokens \
 *     --slow \
 *     --multi \
 *     --verify \
 *     --broadcast
 */
contract DeployMockTokens is DeployBaseRelease {
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
    address public constant DEFAULT_CREATE3_DEPLOYER = 0x6F6cA5F50B6b99a7298B4b7fE7E4Daa1f90552a2;

    address internal deployerAddress;

    error DEPLOYER_ADDRESS_NOT_SET();
    error DEPLOYER_NOT_FOUND();

    function setUp() public override {
        configPath = "deployment-config-testnet.json";
        super.setUp();
        key = vm.envUint("PRIVATE_KEY");
        deployerAddress = vm.envOr("CREATE3_DEPLOYER_ADDRESS", DEFAULT_CREATE3_DEPLOYER);
        if (deployerAddress == address(0)) {
            revert DEPLOYER_ADDRESS_NOT_SET();
        }
    }

    /// @notice Deploys USDCMock and wstETHMock tokens for testnet deployment
    function run() public {
        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            console.log("\n=== Deploying Mock Tokens to %s ===", network);

            forks[network] = vm.createSelectFork(network);
            if (deployerAddress.code.length == 0) {
                console.log("Deployer not found on %s at %s", network, deployerAddress);
                revert DEPLOYER_NOT_FOUND();
            }
            Deployer deployer = Deployer(payable(deployerAddress));
            address owner = vm.envAddress("DEPLOYER_ADDRESS");

            console.log("Deployer/Owner:", owner);
            console.log("");

            // Deploy USDC Mock
            TokenConfig memory usdcConfig =
                TokenConfig({name: "USDC Mock", symbol: "USDC-M", decimals: 6, mintLimit: USDC_LIMIT});

            string memory configSalt = vm.envString("DEPLOY_SALT");

            address usdcMock = deployToken(deployer, usdcConfig, owner, configSalt);

            // Deploy wstETH Mock
            TokenConfig memory wstethConfig =
                TokenConfig({name: "wstETH Mock", symbol: "wstETH-M", decimals: 18, mintLimit: WSTETH_LIMIT});

            address wstethMock = deployToken(deployer, wstethConfig, owner, configSalt);

            // Print summary
            console.log("\n=== Deployment Summary (%s) ===", network);
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
            console.log("1. Update deployment-config-testnet.json for %s with these addresses:", network);
            console.log("   - USDCMock: %s", usdcMock);
            console.log("   - wstETHMock: %s", wstethMock);
            console.log("-------------------- DONE");
        }
    }

    function deployToken(Deployer deployer, TokenConfig memory config, address owner, string memory configSalt)
        internal
        returns (address)
    {
        console.log("Deploying %s...", config.name);

        string memory saltLabel = string.concat(config.symbol, "-", configSalt);
        bytes32 salt = _tokenSalt(saltLabel);
        console.log("  Salt for %s:", config.symbol);
        console.log("  Salt label: %s", saltLabel);
        console.logBytes32(salt);

        vm.startBroadcast(key);

        address created = deployer.create(
            salt,
            abi.encodePacked(
                type(ERC20Mock).creationCode,
                abi.encode(config.name, config.symbol, config.decimals, owner, POH_VERIFY, config.mintLimit)
            )
        );

        vm.stopBroadcast();

        console.log("  %s deployed at: %s", config.symbol, created);

        return created;
    }

    function _tokenSalt(string memory saltLabel) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(msg.sender, bytes(saltLabel)));
    }
}
