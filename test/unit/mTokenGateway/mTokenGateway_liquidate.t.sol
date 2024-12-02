// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {BytesLib} from "src/libraries/BytesLib.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_liquidate is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.liquidateOnHost(0, msg.sender, address(0));
    }

    function test_RevertWhen_UserIsAddress0(uint256 amount) external inRange(amount, SMALL, LARGE) {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.liquidateOnHost(amount, address(0), address(0));
    }

    function test_RevertWhen_UserIsMsgSender(uint256 amount) external inRange(amount, SMALL, LARGE) {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.liquidateOnHost(amount, address(this), address(0));
    }

    function test_WhenAmountGreaterThan0(uint256 amount) external inRange(amount, SMALL, LARGE) {
        vm.expectRevert();
        mWethExtension.liquidateOnHost(amount, address(alice), address(0));

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        uint256 wethAmountBefore = weth.balanceOf(address(this));
        mWethExtension.liquidateOnHost(amount, address(alice), address(0));
        uint256 wethAmountAfter = weth.balanceOf(address(this));

        // it should transfer underlying from sender
        assertEq(wethAmountAfter + amount, wethAmountBefore);

        // it should increase nonce for this operation type
        assertEq(
            mWethExtension.getNonce(
                address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.LiquidateOnOtherChain
            ),
            1
        );
        // it should not increase nonce for any other operation type
        assertEq(
            mWethExtension.getNonce(
                address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.MintOnOtherChain
            ),
            0
        );
    }
}
