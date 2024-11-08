// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

contract mTokenGateway_borrow is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.borrow(0);
    }

    function test_WhenAmountGreaterThan0(uint256 amount) external inRange(amount, SMALL, LARGE) {
        _borrowGatewayPrerequisites(address(mWethExtension), amount);

        mWethExtension.borrow(amount);

        // it should update the logs for the caller
        assertEq(mWethExtension.getLogsLength(address(this), ImTokenGateway.OperationType.Borrow), 1);
        assertEq(mWethExtension.getLogsLength(address(this), ImTokenGateway.OperationType.Mint), 1);
        assertEq(mWethExtension.getLogsLength(address(this), ImTokenGateway.OperationType.Repay), 0);

        // it should increase nonce for this operation type
        assertEq(mWethExtension.getNonce(address(this), ImTokenGateway.OperationType.Borrow), 1);

        // it should not increase nonce for any other operation type
        assertEq(mWethExtension.getNonce(address(this), ImTokenGateway.OperationType.Mint), 1);
        assertEq(mWethExtension.getNonce(address(this), ImTokenGateway.OperationType.Repay), 0);
    }
}
