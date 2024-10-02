// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                           
*/

import {Types} from "./utils/Types.sol";
import {Events} from "./utils/Events.sol";
import {Helpers} from "./utils/Helpers.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";

abstract contract Base_Unit_Test is Events, Helpers, Types {
    // ----------- USERS ------------
    address public alice;
    address public bob;
    address public foo;

    // ----------- TOKENS ------------
    ERC20Mock public usdc;
    ERC20Mock public weth;

    function setUp() public virtual {
        alice = _spawnAccount(ALICE_KEY, "Alice");
        bob = _spawnAccount(BOB_KEY, "Bob");
        foo = _spawnAccount(FOO_KEY, "Foo");

        usdc = _deployToken("USDC", "USDC", 6);
        weth = _deployToken("WETH", "WETH", 18);
    }

    // ----------- MODIFIERS ------------
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
