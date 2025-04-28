// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

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

// Mock contracts
contract MockComptroller {
    mapping(address => address[]) public userAssets;
    
    function getAssetsIn(address user) external view returns (address[] memory) {
        return userAssets[user];
    }

    function _addUserMarket(address user, address market) external {
        userAssets[user].push(market);
    }
}

contract MockCToken is ERC20Mock {
    address public underlying;
    mapping(address => uint256) public borrowBalances;
    mapping(address => uint256) public collateralBalances;

    constructor(
        string memory name,
        string memory symbol,
        address underlying_
    ) ERC20Mock(name, symbol, 0) {
        underlying = underlying_;
    }

    function balanceOfUnderlying(address user) external view returns (uint256) {
        return collateralBalances[user];
    }

    function borrowBalanceStored(address user) external view returns (uint256) {
        return borrowBalances[user];
    }

    function redeemUnderlying(uint256 amount) external returns (uint256) {
        collateralBalances[msg.sender] -= amount;
        IERC20(underlying).transfer(msg.sender, amount);
        return 0;
    }

    function repayBorrow(uint256 amount) external returns (uint256) {
        borrowBalances[msg.sender] -= amount;
        IERC20(underlying).transferFrom(msg.sender, address(this), amount);
        return 0;
    }

    // Test helpers
    function setCollateralBalance(address user, uint256 amount) external {
        collateralBalances[user] = amount;
    }

    function setBorrowBalance(address user, uint256 amount) external {
        borrowBalances[user] = amount;
    }
}

contract MigratorMockTest is Test {
    // Test user
    address user;

    // V1 (Mendi) mocked contracts
    MockComptroller mendiComptroller;
    MockCToken mendiUSDC;
    MockCToken mendiWstETH;

    // V2 (Malda) contracts
    Operator operator;
    mErc20Host maldaUSDC;
    mErc20Host maldaWstETH;
    Migrator migrator;

    // Underlying tokens - Linea Mainnet addresses
    IERC20 constant USDC = IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff);
    IERC20 constant wstETH = IERC20(0xB5beDd42000b71FddE22D3eE8a79Bd49A568fC8F);

    function setUp() public {
        // Fork Linea mainnet
        vm.createSelectFork(vm.envString("LINEA_RPC_URL"));

        // Create test user
        user = makeAddr("user");

        // Deploy mock V1 contracts
        mendiComptroller = new MockComptroller();
        mendiUSDC = new MockCToken("Mendi USDC", "mUSDC", address(USDC));
        mendiWstETH = new MockCToken("Mendi wstETH", "mwstETH", address(wstETH));

        // Deploy V2 protocol
        (
            address rolesContract,
            address operator_,
            address maldaUSDC_,
            address maldaWstETH_
        ) = deployV2Protocol();

        operator = Operator(operator_);
        maldaUSDC = mErc20Host(maldaUSDC_);
        maldaWstETH = mErc20Host(maldaWstETH_);

        // Deploy Migrator
        migrator = new Migrator();

        // Set migrator in markets
        vm.startPrank(maldaUSDC.admin());
        maldaUSDC.setMigrator(address(migrator));
        vm.stopPrank();

        vm.startPrank(maldaWstETH.admin());
        maldaWstETH.setMigrator(address(migrator));
        vm.stopPrank();

        // Setup test scenario
        _setupTestScenario();
    }

    function testMigrationWithCollateralAndBorrow() public {
        // Start test
        vm.startPrank(user);

        // Execute migration
        Migrator.MigrationParams memory params = Migrator.MigrationParams({
            mendiComptroller: address(mendiComptroller),
            maldaOperator: address(operator)
        });

        migrator.migrateAllPositions(params);

        // Verify positions were migrated correctly
        _verifyPositions();

        vm.stopPrank();
    }

    function _setupTestScenario() internal {
        // Setup user positions in V1
        uint256 usdcCollateral = 10_000e6; // 10,000 USDC
        uint256 wstETHBorrow = 3e18;     // 3 wstETH

        // Deal tokens to mock markets
        deal(address(USDC), address(mendiUSDC), usdcCollateral);
        deal(address(wstETH), address(mendiWstETH), wstETHBorrow);

        // Setup collateral position in USDC market
        mendiUSDC.setCollateralBalance(user, usdcCollateral);
        mendiComptroller._addUserMarket(user, address(mendiUSDC));

        // Setup borrow position in wstETH market
        mendiWstETH.setBorrowBalance(user, wstETHBorrow);
        mendiComptroller._addUserMarket(user, address(mendiWstETH));

        // Deal tokens to user for repaying borrows
        deal(address(wstETH), user, wstETHBorrow);
        vm.prank(user);
        wstETH.approve(address(mendiWstETH), wstETHBorrow);
    }

    function _verifyPositions() internal {
        // Verify USDC position
        uint256 usdcCollateralV1 = mendiUSDC.balanceOfUnderlying(user);
        uint256 usdcCollateralV2 = maldaUSDC.balanceOfUnderlying(user);
        assertEq(usdcCollateralV1, usdcCollateralV2, "USDC collateral mismatch");

        // Verify wstETH position
        uint256 wstETHBorrowV1 = mendiWstETH.borrowBalanceStored(user);
        uint256 wstETHBorrowV2 = maldaWstETH.borrowBalanceStored(user);
        assertEq(wstETHBorrowV1, wstETHBorrowV2, "wstETH borrow mismatch");

        // Additional checks
        assertEq(USDC.balanceOf(address(maldaUSDC)), usdcCollateralV1, "USDC not transferred to V2");
        assertEq(mendiUSDC.balanceOfUnderlying(user), 0, "USDC not withdrawn from V1");
    }

    function deployV2Protocol() internal returns (
        address rolesContract,
        address operatorAddress,
        address usdcMarket,
        address wstETHMarket
    ) {
        // Deploy Create3 deployer
        Deployer deployer = new Deployer(msg.sender);

        // Deploy RBAC
        rolesContract = new DeployRbac().run(deployer);

        // Deploy Oracle with Linea price feeds
        address oracle = new DeployMixedPriceOracleV3().run(
            deployer,
            0x1c58342000044d5e2a2A6D2f3f5014Ef0351Cd9b, // USDC/USD feed on Linea
            0x3c88d11cb29EaB18Eb2AD7E0a0B8a6d252346a07, // wstETH/USD feed on Linea
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

        DeployJumpRateModelV4.InterestData memory wstETHInterest = DeployJumpRateModelV4.InterestData({
            kink: 800000000000000000, // 80%
            name: "wstETH",
            blocksPerYear: 2628000,
            baseRatePerYear: 20000000000000000, // 2%
            multiplierPerYear: 100000000000000000, // 10%
            jumpMultiplierPerYear: 1000000000000000000 // 100%
        });

        address wstETHInterestModel = new DeployJumpRateModelV4().run(deployer, wstETHInterest);

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

        DeployHostMarket.MarketData memory wstETHMarketData = DeployHostMarket.MarketData({
            underlyingToken: address(wstETH),
            operator: operatorAddress,
            interestModel: wstETHInterestModel,
            exchangeRateMantissa: 1e18,
            name: "Malda wstETH",
            symbol: "mwstETH",
            decimals: 18,
            zkVerifier: address(0), // Not needed for test
            roles: rolesContract
        });

        wstETHMarket = new DeployHostMarket().run(deployer, wstETHMarketData);

        return (rolesContract, operatorAddress, usdcMarket, wstETHMarket);
    }
} 