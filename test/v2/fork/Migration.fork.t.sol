// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Roles} from "src/Roles.sol";
import {Operator} from "src/Operator/Operator.sol";
import {Migrator} from "src/migration/Migrator.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {Risc0VerifierMock} from "test/mocks/Risc0VerifierMock.sol";
import {OracleMock} from "test/mocks/OracleMock.sol";
import {ImToken, ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

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
    address public constant MALDA_WETH_MARKET = 0xC7Bc6bD45Eb84D594f51cED3c5497E6812C7732f;
    address public MALDA_WETH_MARKET_OWNER = 0x91B945CbB063648C44271868a7A0c7BdFf64827D;

    function setUp() public override {
        super.setUp();

        lineaFork = vm.createSelectFork(vm.envString("LINEA_RPC_URL"), 20313469);
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

        operator.supportMarket(0xC7Bc6bD45Eb84D594f51cED3c5497E6812C7732f);
    }

    ////////////////////////////////////////////////////////////
    //                    GetAllPositions                     //
    ////////////////////////////////////////////////////////////

    function test_fork_getAllPositions_success() external pure {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        return;
        // TODO @Cosmin leave for now
        // vm.prank(USER_V1);
        // Migrator.Position[] memory positions = migrator.getAllPositions(USER_V1);

        // assertEq(positions.length, 1);
        // assertGt(positions[0].collateralUnderlyingAmount, 0.01 ether);
        // assertEq(positions[0].maldaMarket, address(MALDA_WETH_MARKET));
    }

    ////////////////////////////////////////////////////////////
    //                GetAllCollateralMarkets                 //
    ////////////////////////////////////////////////////////////

    function test_fork_getAllCollateralMarkets_success() external view {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory positions = migrator.getAllCollateralMarkets(USER_V1);
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(positions.length, 2);
        assertEq(positions[1], WETH_MARKET_V1);
    }

    //The following will revert until a new market is deployed.

    ////////////////////////////////////////////////////////////
    //                  MigrateAllPositions                   //
    ////////////////////////////////////////////////////////////

    function test_fork_migrateAllPositions_revertsWith() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address _prevOwner = MALDA_WETH_MARKET_OWNER;
        MALDA_WETH_MARKET_OWNER = address(this);
        vm.startPrank(MALDA_WETH_MARKET_OWNER);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.AmountIn, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.AmountInHere, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.AmountOut, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.AmountOutHere, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Seize, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Transfer, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Mint, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Borrow, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Repay, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Redeem, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Liquidate, false);
        Operator(migrator.MALDA_OPERATOR())
            .setPaused(MALDA_WETH_MARKET, ImTokenOperationTypes.OperationType.Rebalancing, false);
        vm.stopPrank();
        MALDA_WETH_MARKET_OWNER = _prevOwner;
        vm.startPrank(MALDA_WETH_MARKET_OWNER);
        mErc20Host(MALDA_WETH_MARKET).setMigrator(address(migrator));
        vm.stopPrank();

        uint256 mendiV1Collateral = ImToken(MALDA_WETH_MARKET).balanceOfUnderlying(USER_V1);

        deal(WETH, MALDA_WETH_MARKET, 1 ether);
        vm.startPrank(USER_V1);
        IERC20(WETH_MARKET_V1).approve(address(migrator), type(uint256).max);
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(); //TODO: remove
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        migrator.migrateAllPositions();
        IERC20(MALDA_WETH_MARKET).approve(address(migrator), 0);
        vm.stopPrank();

        uint256 collateralAmount = ImToken(MALDA_WETH_MARKET).balanceOfUnderlying(address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertApproxEqAbs(mendiV1Collateral, collateralAmount, 0.1e18);
    }
}
