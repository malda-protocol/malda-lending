// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";

import {mToken_Unit_Shared} from "test/unit/shared/mToken_Unit_Shared.t.sol";
import {MockFirewall} from "test/mocks/MockFirewall.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract mErc20Host_admin is mToken_Unit_Shared {
    function _hostInitData(
        address underlying_,
        address operator_,
        address interestRateModel_,
        address admin_,
        address zkVerifier_,
        address roles_
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            mErc20Host.initialize.selector,
            underlying_,
            operator_,
            interestRateModel_,
            1e18,
            "Market WETH",
            "mWeth",
            18,
            admin_,
            zkVerifier_,
            roles_
        );
    }

    function testUpdateAllowedChainAsAdmin() external {
        uint32 chainId = uint32(block.chainid);
        mWethHost.updateAllowedChain(chainId, true);
        assertTrue(mWethHost.allowedChains(chainId));
    }

    function testUpdateAllowedChainRevertWhenNotAdminOrRole() external {
        vm.prank(alice);
        vm.expectRevert(ImErc20Host.mErc20Host_CallerNotAllowed.selector);
        mWethHost.updateAllowedChain(uint32(block.chainid), true);
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

    function testExtractForRebalancingRevertWhenNotRebalancer() external {
        vm.prank(alice);
        vm.expectRevert(ImErc20Host.mErc20Host_NotRebalancer.selector);
        mWethHost.extractForRebalancing(1);
    }

    function testSetMigratorUpdates() external {
        address migrator = address(0xBEEF);
        mWethHost.setMigrator(migrator);
        assertEq(mWethHost.migrator(), migrator);
    }

    function testSetMigratorRevertWhenZero() external {
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        mWethHost.setMigrator(address(0));
    }

    function testSetGasHelperUpdates() external {
        address helper = address(0xCAFE);
        mWethHost.setGasHelper(helper);
        assertEq(address(mWethHost.gasHelper()), helper);
    }

    function testSetGasHelperRevertWhenZero() external {
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        mWethHost.setGasHelper(address(0));
    }

    function testInitFirewall_setsFirewallAdmin() external {
        MockFirewall firewall = new MockFirewall();

        mWethHost.initFirewall(address(firewall));

        assertEq(mWethHost.hypernativeFirewallAdmin(), address(this));
    }

    function testWithdrawGasFeesTransfers() external {
        vm.deal(address(mWethHost), 1 ether);
        uint256 receiverBalanceBefore = alice.balance;

        mWethHost.withdrawGasFees(payable(alice));

        assertEq(address(mWethHost).balance, 0);
        assertEq(alice.balance, receiverBalanceBefore + 1 ether);
    }

    function testWithdrawGasFeesRevertWhenReceiverZero() external {
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        mWethHost.withdrawGasFees(payable(address(0)));
    }

    function testUpdateZkVerifierUpdates() external {
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        mWethHost.updateZkVerifier(address(newVerifier));
        assertEq(address(mWethHost.verifier()), address(newVerifier));
    }

    function testUpdateZkVerifierRevertWhenZero() external {
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        mWethHost.updateZkVerifier(address(0));
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

    function testMintOrBorrowMigrationRevertWhenNotMigrator() external {
        vm.prank(alice);
        vm.expectRevert(ImErc20Host.mErc20Host_CallerNotAllowed.selector);
        mWethHost.mintOrBorrowMigration(true, 1, alice, alice, 0);
    }

    function testMintOrBorrowMigrationRevertWhenAmountZero() external {
        mWethHost.setMigrator(address(this));

        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);
        mWethHost.mintOrBorrowMigration(true, 0, bob, address(this), 0);
    }

    function testGetProofDataReturnsAccumulators() external view {
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

    function testInitializeRevertWhenUnderlyingZero() external {
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(0), address(operator), address(interestModel), address(this), address(zkVerifier), address(roles)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenOperatorZero() external {
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(0), address(interestModel), address(this), address(zkVerifier), address(roles)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenInterestModelZero() external {
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(0), address(this), address(zkVerifier), address(roles)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenZkVerifierZero() external {
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(interestModel), address(this), address(0), address(roles)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenRolesZero() external {
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(interestModel), address(this), address(zkVerifier), address(0)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function testInitializeRevertWhenAdminZero() external {
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(interestModel), address(0), address(zkVerifier), address(roles)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }
}
