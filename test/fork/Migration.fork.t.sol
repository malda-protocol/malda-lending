// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Roles} from "src/Roles.sol";
import {Operator} from "src/Operator/Operator.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";
import {Migrator} from "src/migration/Migrator.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {Risc0VerifierMock} from "test/mocks/Risc0VerifierMock.sol";
import {OracleMock} from "test/mocks/OracleMock.sol";
import {ImToken, ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {IMendiComptroller, IMendiMarket} from "src/migration/IMigrator.sol";
import {BaseForkTest} from "test/utils/BaseForkTest.t.sol";

interface IWETH {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IMendiComptrollerExt is IMendiComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory results);
}

interface IMendiErc20Market is IMendiMarket {
    function mint(uint256 mintAmount) external returns (uint256 err);
    function borrow(uint256 borrowAmount) external returns (uint256 err);
}

interface IFirewallRegister {
    function firewallRegister(address account) external;
}

interface IMaldaErc20HostAdmin {
    function setMigrator(address _migrator) external;
    function migrator() external view returns (address);
}

contract MigrationForkTest is BaseForkTest {
    address public constant COMPTROLLER = 0x1b4d3b0421dDc1eB216D230Bc01527422Fb93103;

    Roles public roles;
    Migrator public migrator;
    Operator public operator;
    ZkVerifier public zkVerifier;
    RewardDistributor public rewards;
    JumpRateModelV4 public interestModel;
    Risc0VerifierMock public verifierMock;
    OracleMock public oracleOperator;

    address public constant USER_V1 = 0xdca17BA9c04e1eae0356824Acd6ECFD053CDE028;
    address public constant WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address public constant WETH_MARKET_V1 = 0xAd7f33984bed10518012013D4aB0458D37FEE6F3;
    address public constant USDC_MARKET_V1 = 0x333D8b480BDB25eA7Be4Dd87EEB359988CE1b30D;
    // NOTE: This is the WETH market included in Migrator.allowedMarkets (see Migrator constructor allow list).
    address public constant MALDA_WETH_MARKET = 0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99;
    address public MALDA_WETH_MARKET_OWNER = 0x91B945CbB063648C44271868a7A0c7BdFf64827D;

    uint256 internal constant ETH_FUND_FOR_STANDARD_MIGRATION = 0.01 ether;
    uint256 internal constant ETH_FUND_FOR_COLLATERAL_ONLY = 0.02 ether;
    uint256 internal constant ETH_FUND_FOR_UNSUPPORTED_BORROW = 0.03 ether;
    uint256 internal constant ETH_FUND_FOR_BORROW_MIGRATION = 0.08 ether;
    uint256 internal constant ETH_SPLIT_DIVISOR = 2;
    string internal constant NO_MENDI_POSITIONS_ERR = "[Migrator] No Mendi positions";

    function setUp() public override {
        super.setUp();

        lineaFork = vm.createSelectFork(vm.envString("LINEA_RPC_URL"), 24_326_770);
        _selectLineaFork();

        roles = new Roles(address(this));
        vm.label(address(roles), "Roles");

        RewardDistributor rewardsImpl = new RewardDistributor();
        bytes memory rewardsInitData = abi.encodeWithSelector(RewardDistributor.initialize.selector, address(this));
        ERC1967Proxy rewardsProxy = new ERC1967Proxy(address(rewardsImpl), rewardsInitData);
        rewards = RewardDistributor(address(rewardsProxy));
        vm.makePersistent(address(rewards));
        vm.label(address(rewards), "RewardDistributor");

        Operator oprImp = new Operator();
        bytes memory operatorInitData =
            abi.encodeWithSelector(Operator.initialize.selector, address(roles), address(this), address(this));
        ERC1967Proxy operatorProxy = new ERC1967Proxy(address(oprImp), operatorInitData);
        operator = Operator(address(operatorProxy));
        vm.label(address(operator), "Operator");
        rewards.setOperator(address(operator));

        migrator = new Migrator(address(operatorProxy));

        verifierMock = new Risc0VerifierMock();
        vm.label(address(verifierMock), "verifierMock");

        zkVerifier = new ZkVerifier(address(this), "0x123", address(verifierMock));
        vm.label(address(zkVerifier), "ZkVerifier contract");

        interestModel = new JumpRateModelV4(
            31536000, 0, 1981861998, 43283866057, 800000000000000000, address(this), "InterestModel"
        );
        vm.label(address(interestModel), "InterestModel");

        oracleOperator = new OracleMock(address(this));
        vm.label(address(oracleOperator), "oracleOperator");

        // **** SETUP ****
        rewards.setOperator(address(operator));
        operator.setPriceOracle(address(oracleOperator));

        operator.supportMarket(MALDA_WETH_MARKET);
    }

    ////////////////////////////////////////////////////////////
    //                    GetAllPositions                     //
    ////////////////////////////////////////////////////////////

    function test_fork_getAllPositions_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IMendiMarket[] memory mendiMarkets = IMendiComptroller(COMPTROLLER).getAssetsIn(USER_V1);

        address[8] memory allowedMarkets = [
            address(0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b),
            address(0x6AECeD8e67964Eb6d0Ae7B159D27eF07F6c11b99),
            address(0x66DfCBf23319D68bdF0cB57797Fcc0A64d2265f8),
            address(0x0E5ad58f827f53C9F92c71319b77772F2a1FBdb2),
            address(0xe79a5f1E2E5619dF1cbb089Db3B11ff9E4dA5aff),
            address(0x867B44af79da71684508c25a1323db3cce5bC23D),
            address(0x301E5481271fD4F4f4C0291F88d7d829c64E2B2b),
            address(0xa31963C753f277f7d82d98F56b2C374256925eB7)
        ];

        bool supportedAny;
        for (uint256 i; i < allowedMarkets.length; ++i) {
            address market = allowedMarkets[i];
            if (!migrator.allowedMarkets(market)) continue;

            // Only add markets that look like real mTokens so Migrator won't revert when calling `underlying()`.
            (bool ok, bytes memory ret) = market.staticcall(abi.encodeWithSelector(bytes4(keccak256("underlying()"))));
            if (!ok || ret.length < 32) continue;

            address marketUnderlying = abi.decode(ret, (address));

            for (uint256 j; j < mendiMarkets.length; ++j) {
                IMendiMarket mendiMarket = mendiMarkets[j];

                uint256 collateral = mendiMarket.balanceOfUnderlying(USER_V1);
                uint256 borrow = mendiMarket.borrowBalanceStored(USER_V1);
                if (collateral == 0 && borrow == 0) continue;

                if (mendiMarket.underlying() == marketUnderlying) {
                    operator.supportMarket(market);
                    supportedAny = true;
                    break;
                }
            }
        }

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        Migrator.Position[] memory positions = migrator.getAllPositions(USER_V1);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        if (!supportedAny) {
            assertEq(
                positions.length,
                0,
                "expected no migratable positions because no allowed malda markets match the user's active mendi positions"
            );
            return;
        }

        assertGt(positions.length, 0, "expected at least one migratable position");
        for (uint256 i; i < positions.length; ++i) {
            assertTrue(positions[i].mendiMarket != address(0), "position.mendiMarket is zero");
            assertTrue(positions[i].maldaMarket != address(0), "position.maldaMarket is zero");
            assertTrue(migrator.allowedMarkets(positions[i].maldaMarket), "position.maldaMarket is not in allow list");

            assertEq(
                ImToken(positions[i].maldaMarket).underlying(),
                IMendiMarket(positions[i].mendiMarket).underlying(),
                "position underlying mismatch between mendi market and malda market"
            );

            assertTrue(
                positions[i].collateralUnderlyingAmount > 0 || positions[i].borrowAmount > 0,
                "position has neither collateral nor borrow"
            );
        }
    }

    function test_fork_getAllPositions_success_whenUnsupportedUnderlyingIsPresent() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user = makeAddr("UnsupportedMarketUser");
        uint256 funded = _fundUserWithEth(user, ETH_FUND_FOR_UNSUPPORTED_BORROW);
        uint256 wethToSupply = funded / ETH_SPLIT_DIVISOR;
        assertGt(wethToSupply, 0, "insufficient ETH to open base collateral position");

        _openMendiWethCollateralOnlyPosition(user, wethToSupply);
        _borrowFromUnsupportedMendiMarket(user);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        Migrator.Position[] memory positions = migrator.getAllPositions(user);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(positions.length, 1, "only supported WETH market should be migratable");
        assertEq(positions[0].maldaMarket, MALDA_WETH_MARKET, "unexpected migratable market");
        assertEq(positions[0].mendiMarket, WETH_MARKET_V1, "unexpected mendi market in migratable set");
    }

    ////////////////////////////////////////////////////////////
    //                GetAllCollateralMarkets                 //
    ////////////////////////////////////////////////////////////

    function test_fork_getAllCollateralMarkets_success() external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IMendiMarket[] memory markets = IMendiComptroller(COMPTROLLER).getAssetsIn(USER_V1);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory positions = migrator.getAllCollateralMarkets(USER_V1);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(positions.length, markets.length, "positions length does not match comptroller assetsIn length");

        for (uint256 i; i < markets.length; ++i) {
            uint256 collateral = markets[i].balanceOf(USER_V1);
            if (collateral == 0) {
                assertEq(positions[i], address(0), "position is non-zero for a market with no collateral");
            } else {
                assertEq(
                    positions[i],
                    address(markets[i]),
                    "position does not match the collateral market returned by the comptroller"
                );
            }
        }
    }

    function test_fork_getAllCollateralMarkets_success_whenUserHasCollateral() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user = makeAddr("UserWithCollateral");
        uint256 funded = _fundUserWithEth(user, ETH_FUND_FOR_COLLATERAL_ONLY);
        uint256 wethToSupply = funded / ETH_SPLIT_DIVISOR;
        assertGt(wethToSupply, 0, "insufficient ETH to open collateral position");

        _openMendiWethCollateralOnlyPosition(user, wethToSupply);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory positions = migrator.getAllCollateralMarkets(user);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(positions.length, 1, "expected one collateral market for test user");
        assertEq(positions[0], WETH_MARKET_V1, "unexpected collateral market");
    }

    ////////////////////////////////////////////////////////////
    //                  MigrateAllPositions                   //
    ////////////////////////////////////////////////////////////

    function test_fork_migrateAllPositions_success() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user = makeAddr("MigrationUser");

        uint256 ethFunded = _fundUserWithEth(user, ETH_FUND_FOR_STANDARD_MIGRATION);

        // Leave some ETH for potential value transfers in future migrations; only use part as WETH collateral.
        uint256 wethToSupply = ethFunded / ETH_SPLIT_DIVISOR;
        assertGt(wethToSupply, 0, "funded ETH is too small to create a mendi WETH position");

        _openMendiWethCollateralOnlyPosition(user, wethToSupply);
        _configureMaldaMarketForMigration(MALDA_WETH_MARKET, user);

        Migrator.Position memory position = _getSinglePosition(user);
        assertEq(position.mendiMarket, WETH_MARKET_V1, "migratable position is not the mendi WETH market");
        assertEq(position.maldaMarket, MALDA_WETH_MARKET, "migratable position is not the malda WETH market");
        assertEq(position.borrowAmount, 0, "expected collateral-only position (borrow amount is non-zero)");
        assertGt(position.collateralUnderlyingAmount, 0, "migration user has no mendi collateral to migrate");

        uint256 wethBalanceBefore = IWETH(WETH).balanceOf(MALDA_WETH_MARKET);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, MALDA_WETH_MARKET);
        emit ImErc20Host.mErc20Host_MintMigration(user, position.collateralUnderlyingAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        migrator.migrateAllPositions();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(IERC20(WETH_MARKET_V1).balanceOf(user), 0, "user still holds v1 cTokens after migration");
        uint256 wethBalanceAfter = IWETH(WETH).balanceOf(MALDA_WETH_MARKET);
        assertGt(wethBalanceAfter, wethBalanceBefore, "malda market WETH balance did not increase after migration");
        assertGt(ImToken(MALDA_WETH_MARKET).balanceOf(user), 0, "user did not receive v2 collateral after migration");
    }

    function test_fork_migrateAllPositions_revertsWith_NoMendiPositions() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user = makeAddr("UserNoMendiPositions");
        IMendiMarket[] memory mendiMarkets = IMendiComptroller(COMPTROLLER).getAssetsIn(user);
        Migrator.Position[] memory positions = migrator.getAllPositions(user);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(mendiMarkets.length, 0, "test user unexpectedly has mendi markets in comptroller.getAssetsIn()");
        assertEq(positions.length, 0, "test user unexpectedly has migratable positions");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(bytes(NO_MENDI_POSITIONS_ERR));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        migrator.migrateAllPositions();
    }

    function test_fork_migrateAllPositions_revertsWith_Operator_Paused_whenMintPaused() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user = makeAddr("UserMintPaused");

        uint256 ethFunded = _fundUserWithEth(user, ETH_FUND_FOR_STANDARD_MIGRATION);
        uint256 wethToSupply = ethFunded / ETH_SPLIT_DIVISOR;
        assertGt(wethToSupply, 0, "funded ETH is too small to create a mendi WETH position");

        _openMendiWethCollateralOnlyPosition(user, wethToSupply);
        _configureMaldaMarketForMigration(MALDA_WETH_MARKET, user);

        address maldaOperator = ImToken(MALDA_WETH_MARKET).operator();
        address operatorOwner = Operator(maldaOperator).owner();

        vm.prank(operatorOwner);
        Operator(maldaOperator).setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Mint, true);

        bool isPaused = Operator(maldaOperator).isPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Mint);
        assertTrue(isPaused, "mint operation is not paused on the malda operator");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        migrator.migrateAllPositions();
    }

    function test_fork_migrateAllPositions_success_whenUserHasBorrowPosition() external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user = makeAddr("MigrationUserWithBorrow");

        uint256 funded = _fundUserWithEth(user, ETH_FUND_FOR_BORROW_MIGRATION);
        uint256 collateralAmount = funded * 3 / 4;
        uint256 borrowAmount = collateralAmount / 5;
        assertGt(collateralAmount, 0, "collateral amount is zero");
        assertGt(borrowAmount, 0, "borrow amount is zero");

        _openMendiWethPositionWithBorrow(user, collateralAmount, borrowAmount);
        _configureMaldaMarketForMigration(MALDA_WETH_MARKET, user);
        _setMaldaBorrowMin(MALDA_WETH_MARKET, 0);
        _seedMaldaWethLiquidityFromUser(user, borrowAmount);

        Migrator.Position memory position = _getSinglePosition(user);
        assertEq(position.mendiMarket, WETH_MARKET_V1, "migratable position market mismatch");
        assertEq(position.maldaMarket, MALDA_WETH_MARKET, "target malda market mismatch");
        assertGt(position.collateralUnderlyingAmount, 0, "expected non-zero collateral position");
        assertGt(position.borrowAmount, 0, "expected non-zero borrow position");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, MALDA_WETH_MARKET);
        emit ImErc20Host.mErc20Host_MintMigration(user, position.collateralUnderlyingAmount);

        vm.expectEmit(true, false, false, true, MALDA_WETH_MARKET);
        emit ImErc20Host.mErc20Host_BorrowMigration(user, position.borrowAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(user);
        migrator.migrateAllPositions();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(IMendiMarket(WETH_MARKET_V1).borrowBalanceStored(user), 0, "v1 borrow was not repaid");
        assertEq(IERC20(WETH_MARKET_V1).balanceOf(user), 0, "user still holds v1 cTokens after migration");
        assertEq(
            ImToken(MALDA_WETH_MARKET).borrowBalanceStored(user),
            position.borrowAmount,
            "v2 borrow balance does not match migrated borrow amount"
        );
        assertGt(ImToken(MALDA_WETH_MARKET).balanceOf(user), 0, "user did not receive v2 collateral after migration");
    }

    function test_fork_fuzz_fundUserWithEth_success(uint96 maxAmount) external {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address user = makeAddr("FundedUser");
        uint256 boundedMax = bound(uint256(maxAmount), 1, type(uint96).max);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 funded = _fundUserWithEth(user, boundedMax);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(funded, 0, "funded amount should be positive");
        assertLe(funded, boundedMax, "funded amount exceeds max requested");
        assertEq(user.balance, funded, "recipient ETH balance mismatch");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _fundUserWithEth(address recipient, uint256 maxAmount) internal returns (uint256 sent) {
        uint256 available = USER_V1.balance;
        require(available > 0, "USER_V1 has no ETH on this fork");

        // Keep this robust across forks by never attempting to transfer more than the sender has.
        sent = maxAmount;
        if (sent > available) {
            sent = available / 2;
        }
        require(sent > 0, "insufficient ETH to fund");

        vm.prank(USER_V1);
        (bool ok,) = payable(recipient).call{value: sent}("");
        require(ok, "fund migration user failed");
    }

    function _openMendiWethCollateralOnlyPosition(address user, uint256 wethToSupply) internal {
        vm.startPrank(user);
        IWETH(WETH).deposit{value: wethToSupply}();
        IWETH(WETH).approve(WETH_MARKET_V1, type(uint256).max);

        uint256 mintErr = IMendiErc20Market(WETH_MARKET_V1).mint(wethToSupply);
        assertEq(mintErr, 0, "mendi WETH market mint failed");

        address[] memory marketsToEnter = new address[](1);
        marketsToEnter[0] = WETH_MARKET_V1;
        uint256[] memory enterResults = IMendiComptrollerExt(COMPTROLLER).enterMarkets(marketsToEnter);
        assertEq(enterResults.length, 1, "comptroller enterMarkets did not return one result");
        assertEq(enterResults[0], 0, "comptroller enterMarkets failed for WETH market");

        IERC20(WETH_MARKET_V1).approve(address(migrator), type(uint256).max);
        vm.stopPrank();
    }

    function _openMendiWethPositionWithBorrow(address user, uint256 wethToSupply, uint256 wethToBorrow) internal {
        vm.startPrank(user);
        IWETH(WETH).deposit{value: wethToSupply}();
        IWETH(WETH).approve(WETH_MARKET_V1, type(uint256).max);

        uint256 mintErr = IMendiErc20Market(WETH_MARKET_V1).mint(wethToSupply);
        assertEq(mintErr, 0, "mendi WETH market mint failed");

        address[] memory marketsToEnter = new address[](1);
        marketsToEnter[0] = WETH_MARKET_V1;
        uint256[] memory enterResults = IMendiComptrollerExt(COMPTROLLER).enterMarkets(marketsToEnter);
        assertEq(enterResults.length, 1, "comptroller enterMarkets did not return one result");
        assertEq(enterResults[0], 0, "comptroller enterMarkets failed for WETH market");

        uint256 borrowErr = IMendiErc20Market(WETH_MARKET_V1).borrow(wethToBorrow);
        assertEq(borrowErr, 0, "mendi WETH market borrow failed");

        IERC20(WETH_MARKET_V1).approve(address(migrator), type(uint256).max);
        vm.stopPrank();
    }

    function _borrowFromUnsupportedMendiMarket(address user) internal {
        uint256[4] memory attempts = [uint256(1), uint256(10), uint256(1_000), uint256(1_000_000)];

        vm.startPrank(user);
        bool success;
        for (uint256 i; i < attempts.length; ++i) {
            uint256 err = IMendiErc20Market(USDC_MARKET_V1).borrow(attempts[i]);
            if (err == 0) {
                success = true;
                break;
            }
        }
        vm.stopPrank();

        assertTrue(success, "unable to open unsupported mendi borrow position");
    }

    function _seedMaldaWethLiquidityFromUser(address user, uint256 amount) internal {
        vm.startPrank(user);
        uint256 balance = IWETH(WETH).balanceOf(user);
        assertGe(balance, amount, "user lacks WETH to seed malda liquidity");
        IWETH(WETH).approve(MALDA_WETH_MARKET, amount);
        (bool ok,) = MALDA_WETH_MARKET.call(abi.encodeWithSignature("mint(uint256,address,uint256)", amount, user, 0));
        assertTrue(ok, "failed to seed malda liquidity");
        vm.stopPrank();
    }

    function _setMaldaBorrowMin(address maldaMarket, uint256 amount) internal {
        address maldaOperator = ImToken(maldaMarket).operator();
        address operatorOwner = Operator(maldaOperator).owner();

        address[] memory markets = new address[](1);
        markets[0] = maldaMarket;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.prank(operatorOwner);
        Operator(maldaOperator).setBorrowSizeMin(markets, amounts);
    }

    function _configureMaldaMarketForMigration(address maldaMarket, address user) internal {
        address maldaMarketAdmin = ImToken(maldaMarket).admin();
        vm.prank(maldaMarketAdmin);
        IMaldaErc20HostAdmin(maldaMarket).setMigrator(address(migrator));
        assertEq(IMaldaErc20HostAdmin(maldaMarket).migrator(), address(migrator), "malda market migrator was not set");

        // Some deployed markets may not expose `firewallRegister` (older deployments).
        // If it's present, register the migrator and advance time to satisfy any registration delay.
        (bool registerOk,) = maldaMarket.call(abi.encodeWithSignature("firewallRegister(address)", address(migrator)));
        if (registerOk) {
            vm.warp(block.timestamp + 10 minutes);
        }

        address maldaOperator = ImToken(maldaMarket).operator();
        _disableOperatorFirewall(maldaOperator);

        address operatorOwner = Operator(maldaOperator).owner();

        vm.startPrank(operatorOwner);
        _unpauseAllMarketOperations(maldaOperator, maldaMarket);
        Operator(maldaOperator).setWhitelistedUser(user, true);
        vm.stopPrank();
    }

    function _disableOperatorFirewall(address operatorAddr) internal {
        address firewallAdmin = Operator(operatorAddr).hypernativeFirewallAdmin();

        vm.prank(firewallAdmin);
        Operator(operatorAddr).setFirewall(address(0));
    }

    function _getSinglePosition(address user) internal returns (Migrator.Position memory position) {
        Migrator.Position[] memory positions = migrator.getAllPositions(user);
        assertEq(positions.length, 1, "expected exactly one migratable position");
        return positions[0];
    }

    function _unpauseAllMarketOperations(address operatorAddr, address market) internal {
        Operator op = Operator(operatorAddr);

        op.setPaused(market, ImTokenOperationTypes.OperationType.AmountIn, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.AmountInHere, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.AmountOut, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.AmountOutHere, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Seize, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Transfer, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Mint, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Borrow, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Repay, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Redeem, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Liquidate, false);
        op.setPaused(market, ImTokenOperationTypes.OperationType.Rebalancing, false);
    }
}
