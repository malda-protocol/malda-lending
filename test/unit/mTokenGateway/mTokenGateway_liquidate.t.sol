// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_liquidate is mToken_Unit_Shared {
    function setUp() public virtual override {
        super.setUp();

        vm.chainId(LINEA_CHAIN_ID);
    }

    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.liquidate(address(0x123), 0, address(mWethHost), address(this));
    }

    function test_RevertWhen_MarketPaused(uint256 amount) external inRange(amount, SMALL, LARGE) {
        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.Liquidate, true);

        // it should revert
        vm.expectRevert();
        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));
    }

    function test_RevertWhen_AmountInPaused(uint256 amount) external inRange(amount, SMALL, LARGE) {
        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // it should revert
        vm.expectRevert();
        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));
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
        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));
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

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this),
            address(this),
            amount,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            address(0x123),
            address(mWethHost)
        );

        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }

    function test_GivenUserHasEnoughBalance_ButBlacklisted(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenAmountGreaterThan0
    {
        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(address(this));
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));
    }

    function test_GivenUserHasEnoughBalance_ButReceiverBlacklisted(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenAmountGreaterThan0
    {
        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(address(0x456)); // Blacklist receiver
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(0x456));
    }

    function test_GivenUserHasEnoughBalance_ButWhitelistEnabled(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenAmountGreaterThan0
    {
        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);

        mWethExtension.enableWhitelist();

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);
        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));

        mWethExtension.setWhitelistedUser(address(this), false);
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);
        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));

        mWethExtension.setWhitelistedUser(address(this), true);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this),
            address(this),
            amount,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            address(0x123),
            address(mWethHost)
        );

        mWethExtension.liquidate(address(0x123), amount, address(mWethHost), address(this));

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }

    function test_LiquidateWithDifferentParameters() external {
        uint256 amount = 1 ether;
        address userToLiquidate = address(0x789);
        address collateral = address(mDaiHost);
        address receiver = address(0x456);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), receiver, amount, uint32(block.chainid), LINEA_CHAIN_ID, userToLiquidate, collateral
        );

        mWethExtension.liquidate(userToLiquidate, amount, collateral, receiver);

        // Verify accAmountIn increased for the receiver
        assertEq(mWethExtension.accAmountIn(receiver), amount);
    }

    function test_LiquidateWithGasFee() external {
        uint256 amount = 1 ether;
        uint256 gasFee = 0.01 ether;

        mWethExtension.setGasFee(gasFee);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this),
            address(this),
            amount,
            uint32(block.chainid),
            LINEA_CHAIN_ID,
            address(0x123),
            address(mWethHost)
        );

        mWethExtension.liquidate{value: gasFee}(address(0x123), amount, address(mWethHost), address(this));

        // Verify the gas fee was received
        assertEq(address(mWethExtension).balance, gasFee);
    }

    function test_RevertWhen_NotEnoughGasFee() external {
        uint256 amount = 1 ether;
        uint256 gasFee = 0.01 ether;

        mWethExtension.setGasFee(gasFee);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        vm.expectRevert(ImTokenGateway.mTokenGateway_NotEnoughGasFee.selector);
        mWethExtension.liquidate{value: gasFee - 0.001 ether}(address(0x123), amount, address(mWethHost), address(this));
    }
}
