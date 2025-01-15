// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                           
*/

//contracts
import {Roles} from "src/Roles.sol";
import {Operator} from "src/Operator/Operator.sol";
import {RewardDistributor} from "src/rewards/RewardDistributor.sol";
import {JumpRateModelV4} from "src/interest/JumpRateModelV4.sol";

import {Types} from "./utils/Types.sol";
import {Events} from "./utils/Events.sol";
import {Helpers} from "./utils/Helpers.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {OracleMock} from "./mocks/OracleMock.sol";

abstract contract Base_Unit_Test is Events, Helpers, Types {
    // ----------- USERS ------------
    address public alice;
    address public bob;
    address public foo;

    // ----------- TOKENS ------------
    ERC20Mock public usdc;
    ERC20Mock public weth;
    ERC20Mock public dai;

    // ----------- MALDA ------------
    Roles public roles;
    Operator public operator;
    OracleMock public oracleOperator;
    RewardDistributor public rewards;
    JumpRateModelV4 public interestModel;

    function setUp() public virtual {
        alice = _spawnAccount(ALICE_KEY, "Alice");
        bob = _spawnAccount(BOB_KEY, "Bob");
        foo = _spawnAccount(FOO_KEY, "Foo");

        usdc = _deployToken("USDC", "USDC", 6);
        weth = _deployToken("WETH", "WETH", 18);
        dai = _deployToken("DAI", "DAI", 18);

        roles = new Roles(address(this));
        vm.label(address(roles), "Roles");

        rewards = new RewardDistributor();
        vm.label(address(rewards), "RewardDistributor");

        operator = new Operator(address(roles), address(rewards), address(this));
        vm.label(address(operator), "Operator");

        interestModel = new JumpRateModelV4(
            31536000, 0, 1981861998, 43283866057, 800000000000000000, address(this), "InterestModel"
        );
        vm.label(address(interestModel), "InterestModel");

        oracleOperator = new OracleMock();
        vm.label(address(oracleOperator), "oracleOperator");

        // **** SETUP ****
        rewards.initialize(address(this));
        rewards.setOperator(address(operator));
        operator.setPriceOracle(address(oracleOperator));
    }

    // ----------- MODIFIERS ------------
    modifier whenPriceIs(uint256 price) {
        oracleOperator.setPrice(price);
        _;
    }

    modifier whenUnderlyingPriceIs(uint256 price) {
        oracleOperator.setUnderlyingPrice(price);
        _;
    }

    modifier inRange(uint256 _value, uint256 _min, uint256 _max) {
        vm.assume(_value >= _min && _value <= _max);
        _;
    }

    modifier resetContext(address _executor) {
        _resetContext(_executor);
        _;
    }

    modifier erc20Approved(address _token, address _executor, address _on, uint256 _amount) {
        _erc20Approve(_token, _executor, _on, _amount);
        _;
    }
}
