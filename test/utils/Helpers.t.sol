// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {Constants} from "test/utils/Constants.t.sol";

abstract contract Helpers is Test, Constants {
    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _resetContext(address executor) internal {
        vm.stopPrank();
        vm.startPrank(executor);
    }

    function _erc20Approve(address token, address executor, address on, uint256 amount) internal {
        _resetContext(executor);
        IERC20(token).approve(on, amount);
    }

    function _getTokens(ERC20Mock token, address to, uint256 amount) internal {
        token.mint(to, amount);
    }

    function _spawnAccount(uint256 key, string memory label, uint256 ethAmount) internal returns (address) {
        address user = vm.addr(key);
        vm.deal(user, ethAmount);
        vm.label(user, label);
        return user;
    }

    function _deployToken(string memory name, string memory symbol, uint8 decimals) internal returns (ERC20Mock) {
        ERC20Mock token = new ERC20Mock(name, symbol, decimals, address(this), address(0), type(uint256).max);
        vm.label(address(token), name);
        return token;
    }
}
