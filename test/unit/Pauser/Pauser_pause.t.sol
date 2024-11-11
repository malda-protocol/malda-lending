// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IRoles} from "src/interfaces/IRoles.sol";
import {IPauser} from "src/interfaces/IPauser.sol";
import {Pauser_Unit_Shared} from "../shared/Pauser_Unit_Shared.t.sol";

contract Pauser_pause is Pauser_Unit_Shared {
    function test_WhenContractDoesNotHaveThePAUSE_MANAGERRole() external {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);

        // it should revert for emergencyPauseAll
        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);
        pauser.emergencyPauseAll();

        // it should revert for emergencyPauseMarket
        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);
        pauser.emergencyPauseMarket(address(mWethHost));

        // it should revert for emergencyPauseMarketFor
        vm.expectRevert(IPauser.Pauser_NotAuthorized.selector);
        pauser.emergencyPauseMarketFor(address(mWethHost), IRoles.Pause.MintOnOtherChain);
    }

    modifier whenContractHasThePAUSE_MANAGERRole() {
        roles.allowFor(address(this), roles.PAUSE_MANAGER(), true);
        roles.allowFor(address(pauser), roles.GUARDIAN_PAUSE(), true);
        _;
    }

    function test_GivenEmergencyPauseMarketIsCalled() external whenContractHasThePAUSE_MANAGERRole {
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);

        assertFalse(operator.isPaused(address(mWethHost), IRoles.Pause.Mint));
        pauser.emergencyPauseMarket(address(mWethHost));
        // it should pause all market operations
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Mint));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Seize));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Transfer));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Borrow));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Repay));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Redeem));

        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);
        assertFalse(mWethExtension.isPaused(IRoles.Pause.Mint));
        pauser.emergencyPauseMarket(address(mWethExtension));
        // it should pause all market operations
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Mint));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.MintOnOtherChain));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Seize));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Transfer));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Borrow));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.BorrowOnOtherChain));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Repay));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.RepayOnOtherChain));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Redeem));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.RedeemOnOtherChain));
    }

    function test_GivenEmergencyPauseMarketForIsCalled() external whenContractHasThePAUSE_MANAGERRole {
        // it should only pause a specific operation type
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        assertFalse(operator.isPaused(address(mWethHost), IRoles.Pause.Mint));
        pauser.emergencyPauseMarketFor(address(mWethHost), IRoles.Pause.Mint);
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Mint));
        assertFalse(operator.isPaused(address(mWethHost), IRoles.Pause.Redeem));

        // it should only pause a specific operation type
        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);
        assertFalse(mWethExtension.isPaused(IRoles.Pause.Mint));
        pauser.emergencyPauseMarketFor(address(mWethExtension), IRoles.Pause.Mint);
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Mint));
        assertFalse(mWethExtension.isPaused(IRoles.Pause.MintOnOtherChain));
    }

    function test_GivenEmergencyPauseAllIsCalled() external whenContractHasThePAUSE_MANAGERRole {
        // it should pause all registered markets
        pauser.addPausableMarket(address(mWethHost), IPauser.PausableType.Host);
        pauser.addPausableMarket(address(mWethExtension), IPauser.PausableType.Extension);
        pauser.emergencyPauseAll();

        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Mint));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Seize));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Transfer));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Borrow));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Repay));
        assertTrue(operator.isPaused(address(mWethHost), IRoles.Pause.Redeem));

        assertTrue(mWethExtension.isPaused(IRoles.Pause.Mint));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.MintOnOtherChain));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Seize));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Transfer));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Borrow));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.BorrowOnOtherChain));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Repay));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.RepayOnOtherChain));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.Redeem));
        assertTrue(mWethExtension.isPaused(IRoles.Pause.RedeemOnOtherChain));
    }
}
