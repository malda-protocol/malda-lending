// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

import {mToken_Unit_Shared} from "test/unit/shared/mToken_Unit_Shared.t.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract mTokenGateway_admin is mToken_Unit_Shared {
    function _gatewayInitData(
        address underlying,
        address rolesAddress,
        address blacklisterAddress,
        address verifierAddress
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            mTokenGateway.initialize.selector,
            payable(address(this)),
            underlying,
            rolesAddress,
            blacklisterAddress,
            verifierAddress
        );
    }

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

    function testSetBlacklisterRevertWhenZero() external {
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.setBlacklister(address(0));
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

    function testSetPausedRevertWhenNonOwner() external {
        vm.prank(alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
    }

    function testUnpauseRevertWhenGuardianNotOwner() external {
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
        roles.allowFor(bob, roles.GUARDIAN_PAUSE(), true);

        vm.prank(bob);
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, false);
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

    function testExtractForRebalancingRevertWhenPaused() external {
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.Rebalancing, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                ImTokenGateway.mTokenGateway_Paused.selector, ImTokenOperationTypes.OperationType.Rebalancing
            )
        );
        mWethExtension.extractForRebalancing(1);
    }

    function testExtractForRebalancingRevertWhenNotRebalancer() external {
        vm.prank(alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_NotRebalancer.selector);
        mWethExtension.extractForRebalancing(1);
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

    function testWithdrawGasFeesRevertWhenUnauthorized() external {
        vm.prank(alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.withdrawGasFees(payable(alice));
    }

    function testWithdrawGasFeesRevertWhenReceiverZero() external {
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.withdrawGasFees(payable(address(0)));
    }

    function testUpdateZkVerifierUpdates() external {
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        mWethExtension.updateZkVerifier(address(newVerifier));

        assertEq(address(mWethExtension.verifier()), address(newVerifier));
    }

    function testUpdateZkVerifierRevertWhenZero() external {
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.updateZkVerifier(address(0));
    }

    function testGetProofDataReturnsAccumulators() external view {
        (uint256 amountIn, uint256 amountOut) = mWethExtension.getProofData(alice, 0);
        assertEq(amountIn, 0);
        assertEq(amountOut, 0);
    }

    function testInitializeRevertWhenRolesZero() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(0), address(blacklister), address(zkVerifier));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenVerifierZero() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(roles), address(blacklister), address(0));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenBlacklisterZero() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(roles), address(0), address(zkVerifier));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenUnderlyingZero() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(0), address(roles), address(blacklister), address(zkVerifier));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }
}
