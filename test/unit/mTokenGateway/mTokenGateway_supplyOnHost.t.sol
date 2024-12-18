// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_supplyOnHost is mToken_Unit_Shared {
    function setUp() public virtual override {
        super.setUp();

        vm.chainId(LINEA_CHAIN_ID);
    }

    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.supplyOnHost(0, mTokenGateway_supplyOnHost.test_RevertWhen_AmountIs0.selector);
    }

    function test_RevertWhen_MarketPaused(uint256 amount) external inRange(amount, SMALL, LARGE) {
        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // it should revert
        vm.expectRevert();
        mWethExtension.supplyOnHost(amount, mTokenGateway_supplyOnHost.test_RevertWhen_AmountIs0.selector);
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
        mWethExtension.supplyOnHost(amount, mTokenGateway_supplyOnHost.test_RevertWhen_AmountIs0.selector);
    }

    function test_GivenUserHasEnoughBalance(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenAmountGreaterThan0
    {
        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);
        mWethExtension.supplyOnHost(amount, mTokenGateway_supplyOnHost.test_RevertWhen_AmountIs0.selector);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }
}
