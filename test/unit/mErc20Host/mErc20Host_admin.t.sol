// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20Host_admin is mToken_Unit_Shared {
    function testUpdateAllowedChainAsAdmin() external {
        uint32 chainId = uint32(block.chainid);
        mWethHost.updateAllowedChain(chainId, true);
        assertTrue(mWethHost.allowedChains(chainId));
    }

    function testExtractForRebalancingTransfersUnderlying() external {
        uint256 amount = 1 ether;
        _getTokens(weth, address(mWethHost), amount);
        roles.allowFor(alice, roles.REBALANCER(), true);

        uint256 balanceBefore = weth.balanceOf(alice);
        vm.prank(alice);
        mWethHost.extractForRebalancing(amount);

        assertEq(weth.balanceOf(alice), balanceBefore + amount);
    }

    function testSetMigratorUpdates() external {
        address migrator = address(0xBEEF);
        mWethHost.setMigrator(migrator);
        assertEq(mWethHost.migrator(), migrator);
    }

    function testSetGasHelperUpdates() external {
        address helper = address(0xCAFE);
        mWethHost.setGasHelper(helper);
        assertEq(address(mWethHost.gasHelper()), helper);
    }

    function testWithdrawGasFeesTransfers() external {
        vm.deal(address(mWethHost), 1 ether);
        uint256 receiverBalanceBefore = alice.balance;

        mWethHost.withdrawGasFees(payable(alice));

        assertEq(address(mWethHost).balance, 0);
        assertEq(alice.balance, receiverBalanceBefore + 1 ether);
    }

    function testUpdateZkVerifierUpdates() external {
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        mWethHost.updateZkVerifier(address(newVerifier));
        assertEq(address(mWethHost.verifier()), address(newVerifier));
    }

    function testPerformExtensionCallRevertsOnInvalidAction() external {
        uint32 dstChainId = uint32(block.chainid);
        mWethHost.updateAllowedChain(dstChainId, true);

        vm.expectRevert(ImErc20Host.mErc20Host_ActionNotAvailable.selector);
        mWethHost.performExtensionCall(3, 1, dstChainId);
    }

    function testMintOrBorrowMigrationMints() external {
        operator.supportMarket(address(mWethHost));
        mWethHost.setMigrator(address(this));

        uint256 amount = 2000 ether;
        mWethHost.mintOrBorrowMigration(true, amount, bob, address(this), 0);

        assertGt(mWethHost.balanceOf(bob), 0);
    }

    function testGetProofDataReturnsAccumulators() external {
        (uint256 amountIn, uint256 amountOut) = mWethHost.getProofData(alice, uint32(block.chainid));
        assertEq(amountIn, 0);
        assertEq(amountOut, 0);
    }

    function testLiquidateExternalEmitsEvent() external {
        operator.supportMarket(address(mWethHost));
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(mWethHost), 0.5e18);
        operator.setCloseFactor(0.5e18);

        uint256 supplyAmount = 2000 ether;
        uint256 borrowAmount = 500 ether;
        uint256 repayAmount = 250 ether;

        _getTokens(weth, bob, supplyAmount);
        vm.startPrank(bob);
        weth.approve(address(mWethHost), supplyAmount);
        mWethHost.mint(supplyAmount, bob, 0);
        mWethHost.borrow(borrowAmount);
        vm.stopPrank();

        operator.setCollateralFactor(address(mWethHost), 0);

        uint32 chainId = uint32(block.chainid);
        mWethHost.updateAllowedChain(chainId, true);

        bytes memory journal =
            abi.encodePacked(address(this), address(mWethHost), repayAmount, repayAmount, chainId, chainId, true);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;
        bytes memory journalData = abi.encode(journals);

        address[] memory userToLiquidate = new address[](1);
        userToLiquidate[0] = bob;
        uint256[] memory liquidateAmount = new uint256[](1);
        liquidateAmount[0] = repayAmount;
        address[] memory collateral = new address[](1);
        collateral[0] = address(0);

        vm.expectEmit(true, true, true, true);
        emit ImErc20Host.mErc20Host_LiquidateExternal(
            address(this), address(this), bob, address(this), address(mWethHost), chainId, repayAmount
        );

        mWethHost.liquidateExternal(journalData, "0x123", userToLiquidate, liquidateAmount, collateral, address(this));
    }
}
