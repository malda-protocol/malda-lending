// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Comptroller} from "@mendi/Comptroller.sol";
import {CErc20} from "@mendi/CErc20.sol";
import {CToken} from "@mendi/CToken.sol";

import {Migrator} from "src/migration/Migrator.sol";
import {Operator} from "src/Operator/Operator.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

// Import deployment scripts
import {DeployRbac} from "script/deployment/generic/DeployRbac.s.sol";
import {DeployOperator} from "script/deployment/markets/DeployOperator.s.sol";
import {DeployMixedPriceOracleV3} from "script/deployment/oracles/DeployMixedPriceOracleV3.s.sol";
import {DeployRewardDistributor} from "script/deployment/rewards/DeployRewardDistributor.s.sol";
import {DeployHostMarket} from "script/deployment/markets/host/DeployHostMarket.s.sol";
import {DeployJumpRateModelV4} from "script/deployment/interest/DeployJumpRateModelV4.s.sol";
import {Deployer} from "src/utils/Deployer.sol";

contract MigratorTest is Test {
    // V1 (Mendi) contracts - to be filled with actual addresses
    address constant MENDI_COMPTROLLER = address(0); // TODO: Add Mendi Comptroller address
    address constant MENDI_USDC = address(0);  // TODO: Add Mendi USDC market address
    address constant MENDI_WETH = address(0);  // TODO: Add Mendi WETH market address
    
    // User with complex positions - to be filled
    address constant USER = address(0); // TODO: Add user address with positions

    // V2 (Malda) contracts - will be deployed in setup
    Operator operator;
    mErc20Host maldaUSDC;
    mErc20Host maldaWETH;
    Migrator migrator;

    // Underlying tokens
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        // Deploy V2 protocol
        (
            address rolesContract,
            address operator_,
            address maldaUSDC_,
            address maldaWETH_
        ) = deployV2Protocol();

        operator = Operator(operator_);
        maldaUSDC = mErc20Host(maldaUSDC_);
        maldaWETH = mErc20Host(maldaWETH_);

        // Deploy Migrator
        migrator = new Migrator();

        // Set migrator in markets
        vm.startPrank(maldaUSDC.admin());
        maldaUSDC.setMigrator(address(migrator));
        vm.stopPrank();

        vm.startPrank(maldaWETH.admin());
        maldaWETH.setMigrator(address(migrator));
        vm.stopPrank();
    }

    function testMigration() public {
        // Impersonate user with positions
        vm.startPrank(USER);

        // Execute migration
        Migrator.MigrationParams memory params = Migrator.MigrationParams({
            mendiComptroller: MENDI_COMPTROLLER,
            maldaOperator: address(operator)
        });

        migrator.migrateAllPositions(params);

        // Verify positions were migrated correctly
        _verifyPositions();

        vm.stopPrank();
    }

    function deployV2Protocol() internal returns (
        address rolesContract,
        address operatorAddress,
        address usdcMarket,
        address wethMarket
    ) {
        // Deploy Create3 deployer
        Deployer deployer = new Deployer(msg.sender);

        // Deploy RBAC
        rolesContract = new DeployRbac().run(deployer);

        // Deploy Oracle
        address oracle = new DeployMixedPriceOracleV3().run(
            deployer,
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6, // USDC/USD feed
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // ETH/USD feed
            rolesContract,
            3600 // 1 hour staleness period
        );

        // Deploy Reward Distributor
        address rewardDistributor = new DeployRewardDistributor().run(deployer);

        // Deploy Operator
        operatorAddress = new DeployOperator().run(
            deployer,
            oracle,
            rewardDistributor,
            rolesContract
        );

        // Deploy interest rate models
        DeployJumpRateModelV4.InterestData memory usdcInterest = DeployJumpRateModelV4.InterestData({
            kink: 800000000000000000, // 80%
            name: "USDC",
            blocksPerYear: 2628000, // ~12s blocks
            baseRatePerYear: 20000000000000000, // 2%
            multiplierPerYear: 100000000000000000, // 10%
            jumpMultiplierPerYear: 1000000000000000000 // 100%
        });

        address usdcInterestModel = new DeployJumpRateModelV4().run(deployer, usdcInterest);

        DeployJumpRateModelV4.InterestData memory wethInterest = DeployJumpRateModelV4.InterestData({
            kink: 800000000000000000, // 80%
            name: "WETH",
            blocksPerYear: 2628000,
            baseRatePerYear: 20000000000000000, // 2%
            multiplierPerYear: 100000000000000000, // 10%
            jumpMultiplierPerYear: 1000000000000000000 // 100%
        });

        address wethInterestModel = new DeployJumpRateModelV4().run(deployer, wethInterest);

        // Deploy markets
        DeployHostMarket.MarketData memory usdcMarketData = DeployHostMarket.MarketData({
            underlyingToken: address(USDC),
            operator: operatorAddress,
            interestModel: usdcInterestModel,
            exchangeRateMantissa: 1e18,
            name: "Malda USDC",
            symbol: "mUSDC",
            decimals: 6,
            zkVerifier: address(0), // Not needed for test
            roles: rolesContract
        });

        usdcMarket = new DeployHostMarket().run(deployer, usdcMarketData);

        DeployHostMarket.MarketData memory wethMarketData = DeployHostMarket.MarketData({
            underlyingToken: address(WETH),
            operator: operatorAddress,
            interestModel: wethInterestModel,
            exchangeRateMantissa: 1e18,
            name: "Malda WETH",
            symbol: "mWETH",
            decimals: 18,
            zkVerifier: address(0), // Not needed for test
            roles: rolesContract
        });

        wethMarket = new DeployHostMarket().run(deployer, wethMarketData);

        return (rolesContract, operatorAddress, usdcMarket, wethMarket);
    }

    function _verifyPositions() internal {
        // Get original positions from Mendi
        Comptroller mendi = Comptroller(MENDI_COMPTROLLER);
        CToken[] memory mendiMarkets = mendi.getAssetsIn(USER);

        for (uint256 i = 0; i < mendiMarkets.length; i++) {
            CToken mendiMarket = mendiMarkets[i];
            address underlying = CErc20(address(mendiMarket)).underlying();
            
            // Get corresponding Malda market
            mErc20Host maldaMarket = underlying == address(USDC) ? maldaUSDC : maldaWETH;

            // Compare positions
            uint256 mendiCollateral = mendiMarket.balanceOfUnderlying(USER);
            uint256 mendiBorrow = mendiMarket.borrowBalanceStored(USER);

            uint256 maldaCollateral = maldaMarket.balanceOfUnderlying(USER);
            uint256 maldaBorrow = maldaMarket.borrowBalanceStored(USER);

            assertEq(
                mendiCollateral,
                maldaCollateral,
                "Collateral amount mismatch"
            );
            assertEq(
                mendiBorrow,
                maldaBorrow,
                "Borrow amount mismatch"
            );
        }
    }
} 