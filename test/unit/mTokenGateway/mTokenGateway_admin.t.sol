// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_admin is mToken_Unit_Shared {
    function testInitFirewallAndRegister() external {
        MockFirewall firewall = new MockFirewall();

        mWethExtension.initFirewall(address(firewall));
        mWethExtension.firewallRegister(alice);

        assertEq(firewall.registerCount(), 1);
        assertEq(firewall.lastRegistered(), alice);
    }

    function testSetBlacklisterUpdates() external {
        mWethExtension.setBlacklister(address(blacklister));
        assertEq(address(mWethExtension.blacklistOperator()), address(blacklister));
    }

    function testDisableWhitelist() external {
        mWethExtension.enableWhitelist();
        assertTrue(mWethExtension.whitelistEnabled());

        mWethExtension.disableWhitelist();
        assertFalse(mWethExtension.whitelistEnabled());
    }

    function testSetPausedUnpauseAsOwner() external {
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
        assertTrue(mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn));

        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, false);
        assertFalse(mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn));
    }

    function testExtractForRebalancingTransfersUnderlying() external {
        uint256 amount = 1 ether;
        _getTokens(weth, address(mWethExtension), amount);
        roles.allowFor(alice, roles.REBALANCER(), true);

        uint256 balanceBefore = weth.balanceOf(alice);
        vm.prank(alice);
        mWethExtension.extractForRebalancing(amount);

        assertEq(weth.balanceOf(alice), balanceBefore + amount);
    }

    function testWithdrawGasFeesByOwner() external {
        vm.deal(address(mWethExtension), 1 ether);
        uint256 receiverBalanceBefore = alice.balance;

        mWethExtension.withdrawGasFees(payable(alice));

        assertEq(address(mWethExtension).balance, 0);
        assertEq(alice.balance, receiverBalanceBefore + 1 ether);
    }

    function testWithdrawGasFeesBySequencer() external {
        vm.deal(address(mWethExtension), 1 ether);
        roles.allowFor(bob, roles.SEQUENCER(), true);

        uint256 receiverBalanceBefore = bob.balance;
        vm.prank(bob);
        mWethExtension.withdrawGasFees(payable(bob));

        assertEq(address(mWethExtension).balance, 0);
        assertEq(bob.balance, receiverBalanceBefore + 1 ether);
    }

    function testUpdateZkVerifierUpdates() external {
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        mWethExtension.updateZkVerifier(address(newVerifier));

        assertEq(address(mWethExtension.verifier()), address(newVerifier));
    }

    function testGetProofDataReturnsAccumulators() external {
        (uint256 amountIn, uint256 amountOut) = mWethExtension.getProofData(alice, 0);
        assertEq(amountIn, 0);
        assertEq(amountOut, 0);
    }
}
