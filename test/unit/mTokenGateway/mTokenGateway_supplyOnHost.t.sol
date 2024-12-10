// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_supplyOnHost is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        address[] memory allowedCallers = new address[](0);
        mWethExtension.supplyOnHost(0, address(this), allowedCallers);
    }

    function test_RevertWhen_UserIsAddress0(uint256 amount) external inRange(amount, SMALL, LARGE) {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        address[] memory allowedCallers = new address[](0);
        mWethExtension.supplyOnHost(amount, address(0), allowedCallers);
    }

    function test_RevertWhen_MarketPaused(uint256 amount) external inRange(amount, SMALL, LARGE) {
        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // it should revert
        vm.expectRevert();
        address[] memory allowedCallers = new address[](0);
        mWethExtension.supplyOnHost(amount, address(this), allowedCallers);
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
        address[] memory allowedCallers = new address[](0);
        mWethExtension.supplyOnHost(amount, address(this), allowedCallers);
    }

    function test_GivenUserHasEnoughBalance(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenAmountGreaterThan0
    {
        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 nonceBefore = mWethExtension.nonce();
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);
        address[] memory allowedCallers = new address[](0);
        mWethExtension.supplyOnHost(amount, address(this), allowedCallers);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 nonceAfter = mWethExtension.nonce();
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase nonce
        assertGt(nonceAfter, nonceBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }
}
