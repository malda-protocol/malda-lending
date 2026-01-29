// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {Roles} from "src/Roles.sol";
import {Operator} from "src/Operator/Operator.sol";
import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";
import {Blacklister} from "src/blacklister/Blacklister.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {OracleMock} from "test/mocks/OracleMock.sol";

abstract contract BaseUnitTest is BaseTest {
    ERC20Mock internal usdc;
    ERC20Mock internal weth;
    ERC20Mock internal dai;

    Roles internal roles;
    Operator internal operator;
    OracleMock internal oracleOperator;
    RewardDistributor internal rewards;
    JumpRateModelV4 internal interestModel;
    Blacklister internal blacklister;

    function setUp() public virtual override {
        super.setUp();

        usdc = _deployToken("USDC", "USDC", 6);
        weth = _deployToken("WETH", "WETH", 18);
        dai = _deployToken("DAI", "DAI", 18);

        roles = new Roles(address(this));
        vm.label(address(roles), "Roles");

        RewardDistributor rewardsImpl = new RewardDistributor();
        bytes memory rewardsInitData = abi.encodeWithSelector(RewardDistributor.initialize.selector, address(this));
        ERC1967Proxy rewardsProxy = new ERC1967Proxy(address(rewardsImpl), rewardsInitData);
        rewards = RewardDistributor(address(rewardsProxy));
        vm.label(address(rewards), "RewardDistributor");

        Blacklister blacklisterImp = new Blacklister();
        bytes memory blacklisterInitData =
            abi.encodeWithSelector(Blacklister.initialize.selector, address(this), address(roles));
        ERC1967Proxy blacklisterProxy = new ERC1967Proxy(address(blacklisterImp), blacklisterInitData);
        blacklister = Blacklister(address(blacklisterProxy));
        vm.label(address(blacklister), "Blacklister");

        Operator operatorImpl = new Operator();
        bytes memory operatorInitData =
            abi.encodeWithSelector(Operator.initialize.selector, address(roles), address(blacklister), address(this));
        ERC1967Proxy operatorProxy = new ERC1967Proxy(address(operatorImpl), operatorInitData);
        operator = Operator(address(operatorProxy));
        vm.label(address(operator), "Operator");

        interestModel = new JumpRateModelV4(
            3153600, 792744799, 1981000000, 251900000000, 400000000000000000, address(this), "InterestModel"
        );
        vm.label(address(interestModel), "InterestModel");

        oracleOperator = new OracleMock(address(this));
        vm.label(address(oracleOperator), "OracleOperator");

        rewards.setOperator(address(operator));
        operator.setPriceOracle(address(oracleOperator));
    }

    modifier whenPriceIs(uint256 price) {
        oracleOperator.setPrice(price);
        _;
    }

    modifier whenUnderlyingPriceIs(uint256 price) {
        oracleOperator.setUnderlyingPrice(price);
        _;
    }
}
