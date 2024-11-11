// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

contract mTokenGateway_repay is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.repayOnHost(0);
    }

    modifier whenAmountGreaterThan0() {
        // @dev does nothing; for readability only
        _;
    }

    function test_RevertGiven_UserHasNotEnoughBalance(uint256 amount)
        external
        whenAmountGreaterThan0
        inRange(amount, SMALL, LARGE)
    {
        // it should revert
        vm.expectRevert(); // ERC20InsufficientAllowance
        mWethExtension.repayOnHost(amount);
    }

    function test_GivenUserHasEnoughBalance(uint256 amount)
        external
        whenAmountGreaterThan0
        inRange(amount, SMALL, LARGE)
    {
        _getTokens(weth, address(this), amount);
        _erc20Approve(address(weth), address(this), address(mWethExtension), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));

        mWethExtension.repayOnHost(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should update the logs for the caller
        assertEq(mWethExtension.getLogsLength(address(this), block.chainid, ImTokenGateway.OperationType.Repay), 1);
        assertEq(mWethExtension.getLogsLength(address(this), block.chainid, ImTokenGateway.OperationType.Borrow), 0);

        // it should increase nonce for this operation type
        assertEq(mWethExtension.getNonce(address(this), block.chainid, ImTokenGateway.OperationType.Repay), 1);

        // it should not increase nonce for any other operation type
        assertEq(mWethExtension.getNonce(address(this), block.chainid, ImTokenGateway.OperationType.Mint), 0);
    }
}
