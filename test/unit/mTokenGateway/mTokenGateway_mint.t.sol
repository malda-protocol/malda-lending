// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

contract mTokenGateway_mint is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.mint(0);
    }

    modifier whenAmountGreaterThan0() {
        // @dev does nothing; for readability only
        _;
    }

    function test_RevertGiven_UserHasNotEnoughBalance(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenAmountGreaterThan0
    {
        // it should revert
        weth.approve(address(mWethExtension), amount);
        vm.expectRevert();
        mWethExtension.mint(amount);
    }

    function test_GivenUserHasEnoughBalance(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenAmountGreaterThan0
    {
        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 balanceOfBefore = mWethExtension.balanceOf(address(this));

        weth.approve(address(mWethExtension), amount);
        mWethExtension.mint(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 balanceOfAfter = mWethExtension.balanceOf(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase pending token balance
        assertEq(balanceOfBefore + amount, balanceOfAfter);

        // it should update the logs for the caller
        assertEq(mWethExtension.getLogsLength(address(this), ImTokenGateway.OperationType.Mint), 1);

        // it should increase nonce for this operation type
        assertEq(mWethExtension.getNonce(address(this), ImTokenGateway.OperationType.Mint), 1);

        // it should not increase nonce for any other operation type
        assertEq(mWethExtension.getNonce(address(this), ImTokenGateway.OperationType.Borrow), 0);
    }
}
