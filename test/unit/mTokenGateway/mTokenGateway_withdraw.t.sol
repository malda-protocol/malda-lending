// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

contract mTokenGateway_withdraw is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.repay(0);
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
        vm.expectRevert();
        mWethExtension.repay(amount);
    }

    function test_GivenUserHasEnoughBalance(uint256 amount)
        external
        whenAmountGreaterThan0
        inRange(amount, SMALL, LARGE)
    {
        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);
        mWethExtension.mint(amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethExtension.totalSupply();
        uint256 balanceOfBefore = mWethExtension.balanceOf(address(this));
        uint256 pendingAmountBefore = mWethExtension.pendingAmounts(address(this));

        mWethExtension.withdraw(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethExtension.totalSupply();
        uint256 balanceOfAfter = mWethExtension.balanceOf(address(this));
        uint256 pendingAmountAfter = mWethExtension.pendingAmounts(address(this));

        // it should decrease the caller balance
        assertEq(balanceOfAfter + amount, balanceOfBefore);

        // it should update the logs for the caller
        assertEq(mWethExtension.getLogsLength(address(this), ImTokenGateway.OperationType.Withdraw), 1);
        assertEq(mWethExtension.getLogsLength(address(this), ImTokenGateway.OperationType.Borrow), 0);

        // it should increase nonce for this operation type
        assertEq(mWethExtension.getNonce(address(this), ImTokenGateway.OperationType.Withdraw), 1);

        // it should not increase nonce for any other operation type
        assertEq(mWethExtension.getNonce(address(this), ImTokenGateway.OperationType.Borrow), 0);

        // it should increase pending amount
        assertEq(pendingAmountBefore + amount, pendingAmountAfter);

        // it should decrease total supply
        assertEq(totalSupplyAfter + amount, totalSupplyBefore);

        // it should not change underlying balance
        assertEq(balanceWethBefore, balanceWethAfter);
    }
}
