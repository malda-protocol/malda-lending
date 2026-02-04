// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {CommonLib} from "src/libraries/CommonLib.sol";
import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";
import {mTokenProofDecoderLib} from "src/libraries/mTokenProofDecoderLib.sol";
import {Operator} from "src/Operator/Operator.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";

contract mErc20HostTest is BaseMTokenTest {
    struct LiquidateExternalArgs {
        bytes journalData;
        address[] userToLiquidate;
        uint256[] liquidateAmount;
        address[] collateral;
    }

    uint256 internal constant EXP_SCALE = 1e18;

    function setUp() public override {
        super.setUp();

        mWethHost.updateAllowedChain(uint32(block.chainid), true);
        mDaiHost.updateAllowedChain(uint32(block.chainid), true);
    }

    ////////////////////////////////////////////////////////////
    //                   UpdateAllowedChain                   //
    ////////////////////////////////////////////////////////////

    function test_unit_updateAllowedChain_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 chainId = uint32(block.chainid);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImErc20Host.mErc20Host_ChainStatusUpdated(chainId, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.updateAllowedChain(chainId, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(mWethHost.allowedChains(chainId), "expected condition to be true: mWethHost.allowedChains(chainId)");
    }

    function test_unit_updateAllowedChain_revertsWith_mErc20Host_CallerNotAllowed_revertsWhenNotAdminOrRole() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_CallerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWethHost.updateAllowedChain(uint32(block.chainid), true);
    }

    ////////////////////////////////////////////////////////////
    //                 ExtractForRebalancing                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_extractForRebalancing_success(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, 1e21, 1e24);
        _getTokens(weth, address(mWethHost), amount);
        roles.allowFor(users.alice, roles.REBALANCER(), true);

        uint256 balanceBefore = weth.balanceOf(users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWethHost.extractForRebalancing(amount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            weth.balanceOf(users.alice),
            balanceBefore + amount,
            "expected weth.balanceOf(users.alice) to equal balanceBefore + amount"
        );
    }

    function test_unit_extractForRebalancing_revertsWith_mErc20Host_NotRebalancer_revertsWhenNotRebalancer() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_NotRebalancer.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWethHost.extractForRebalancing(1);
    }

    ////////////////////////////////////////////////////////////
    //                      SetMigrator                       //
    ////////////////////////////////////////////////////////////

    function test_unit_setMigrator_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address migrator = users.bob;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.setMigrator(migrator);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(mWethHost.migrator(), migrator, "expected mWethHost.migrator() to equal migrator");
    }

    function test_unit_setMigrator_revertsWith_mErc20Host_AddressNotValid_revertsWhenZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.setMigrator(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                      SetGasHelper                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setGasHelper_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address helper = users.carol;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.setGasHelper(helper);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(mWethHost.gasHelper()), helper, "expected address(mWethHost.gasHelper()) to equal helper");
    }

    function test_unit_setGasHelper_revertsWith_mErc20Host_AddressNotValid_revertsWhenZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.setGasHelper(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                      InitFirewall                      //
    ////////////////////////////////////////////////////////////

    function test_unit_initFirewall_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockFirewall firewall = new MockFirewall();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit HypernativeFirewallProtected.FirewallAdminChanged(address(0), address(this));
        vm.expectEmit(true, true, true, true);
        emit HypernativeFirewallProtected.FirewallAddressChanged(address(0), address(firewall));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.initFirewall(address(firewall));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWethHost.hypernativeFirewallAdmin(),
            address(this),
            "expected mWethHost.hypernativeFirewallAdmin() to equal address(this)"
        );
    }

    ////////////////////////////////////////////////////////////
    //                        Payable                         //
    ////////////////////////////////////////////////////////////

    function test_unit_payable_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.deal(address(mWethHost), 1 ether);
        uint256 receiverBalanceBefore = users.alice.balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.withdrawGasFees(payable(users.alice));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(mWethHost).balance, 0, "expected address(mWethHost).balance to equal 0");
        assertEq(
            users.alice.balance,
            receiverBalanceBefore + 1 ether,
            "expected users.alice.balance to equal receiverBalanceBefore + 1 ether"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    WithdrawGasFees                     //
    ////////////////////////////////////////////////////////////

    function test_unit_withdrawGasFees_revertsWith_mErc20Host_AddressNotValid_revertsWhenReceiverZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.withdrawGasFees(payable(address(0)));
    }

    ////////////////////////////////////////////////////////////
    //                    UpdateZkVerifier                    //
    ////////////////////////////////////////////////////////////

    function test_unit_updateZkVerifier_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.ZkVerifierUpdated(address(zkVerifier), address(newVerifier));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.updateZkVerifier(address(newVerifier));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(mWethHost.verifier()),
            address(newVerifier),
            "expected address(mWethHost.verifier()) to equal address(newVerifier)"
        );
    }

    function test_unit_updateZkVerifier_revertsWith_mErc20Host_AddressNotValid_revertsWhenZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.updateZkVerifier(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                  PerformExtensionCall                  //
    ////////////////////////////////////////////////////////////

    function test_unit_performExtensionCall_revertsWith_mErc20Host_ActionNotAvailable_revertsOnInvalidAction()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 dstChainId = uint32(block.chainid);
        mWethHost.updateAllowedChain(dstChainId, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_ActionNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.performExtensionCall(3, 1, dstChainId);
    }

    ////////////////////////////////////////////////////////////
    //                 MintOrBorrowMigration                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_mintOrBorrowMigration_success(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWethHost));
        mWethHost.setMigrator(address(this));

        amount = bound(amount, 1e21, 1e24);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImErc20Host.mErc20Host_MintMigration(users.bob, amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintOrBorrowMigration(true, amount, users.bob, address(this), 0);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(mWethHost.balanceOf(users.bob), 0, "expected mWethHost.balanceOf(users.bob) to be greater than 0");
    }

    function test_unit_mintOrBorrowMigration_revertsWith_mErc20Host_CallerNotAllowed_revertsWhenNotMigrator() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_CallerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWethHost.mintOrBorrowMigration(true, 1, users.alice, users.alice, 0);
    }

    function test_unit_mintOrBorrowMigration_revertsWith_mErc20Host_AmountNotValid_revertsWhenAmountZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mWethHost.setMigrator(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintOrBorrowMigration(true, 0, users.bob, address(this), 0);
    }

    ////////////////////////////////////////////////////////////
    //                         Uint32                         //
    ////////////////////////////////////////////////////////////

    function test_fuzz_getProofData_success(address account, uint32 dstChainId) external view {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(account != address(0));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 amountIn, uint256 amountOut) = mWethHost.getProofData(account, dstChainId);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(amountIn, 0, "expected amountIn to equal 0");
        assertEq(amountOut, 0, "expected amountOut to equal 0");
    }

    ////////////////////////////////////////////////////////////
    //                   LiquidateExternal                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_liquidateExternal_success(uint256 repayAmount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWethHost));
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(mWethHost), 0.5e18);
        operator.setCloseFactor(0.5e18);

        uint256 borrowAmount = 500 ether;
        repayAmount = bound(repayAmount, 1, borrowAmount / 2);

        {
            uint256 supplyAmount = 2000 ether;
            _getTokens(weth, users.bob, supplyAmount);
            vm.startPrank(users.bob);
            weth.approve(address(mWethHost), supplyAmount);
            mWethHost.mint(supplyAmount, users.bob, 0);
            mWethHost.borrow(borrowAmount);
            vm.stopPrank();
        }

        operator.setCollateralFactor(address(mWethHost), 0);

        uint32 chainId = uint32(block.chainid);
        mWethHost.updateAllowedChain(chainId, true);

        LiquidateExternalArgs memory args = _buildLiquidateExternalArgs(repayAmount, chainId);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImErc20Host.mErc20Host_LiquidateExternal(
            address(this), address(this), users.bob, address(this), address(mWethHost), chainId, repayAmount
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(
            args.journalData, "0x123", args.userToLiquidate, args.liquidateAmount, args.collateral, address(this)
        );
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_mErc20Host_AddressNotValid_whenUnderlyingZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(0), address(operator), address(interestModel), address(this), address(zkVerifier), address(roles)
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mErc20Host_AddressNotValid_whenOperatorZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(0), address(interestModel), address(this), address(zkVerifier), address(roles)
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mErc20Host_AddressNotValid_whenInterestModelZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(0), address(this), address(zkVerifier), address(roles)
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mErc20Host_AddressNotValid_whenZkVerifierZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(interestModel), address(this), address(0), address(roles)
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mErc20Host_AddressNotValid_whenRolesZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(interestModel), address(this), address(zkVerifier), address(0)
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mErc20Host_AddressNotValid_whenAdminZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host impl = new mErc20Host();
        bytes memory initData = _hostInitData(
            address(weth), address(operator), address(interestModel), address(0), address(zkVerifier), address(roles)
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    ////////////////////////////////////////////////////////////
    //                         Borrow                         //
    ////////////////////////////////////////////////////////////

    function test_unit_borrow_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_EmptyPrice_revertGiven(uint256 amount)
        external
        whenPriceIs(ZERO_VALUE)
        whenUnderlyingPriceIs(ZERO_VALUE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.borrow(amount);
    }

    function test_unit_borrow_revertsWith(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mt_BorrowCashNotAvailable but it actually reverts with InsufficientLiquidity for non cross-chain tokens
        // cannot test this in a non-external flow

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_MarketBorrowCapReached_whenBorrowCapIsReached(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);
        _whenBorrowCapIsReached(address(mWethHost), amount);

        // it should revert with Operator_MarketBorrowCapReached

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_InsufficientLiquidity_whenBorrowTooMuch(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _borrowPrerequisites(address(mWethHost), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.borrow(amount);
    }

    function test_unit_borrow_revertsWith_Operator_InsufficientLiquidity_givenMarketIsNotEntered(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // supply tokens; assure collateral factor is met
        _borrowPrerequisites(address(mWethHost), amount * 2);

        // before state
        uint256 balanceUnderlyingBefore = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenBefore = weth.balanceOf(address(mWethHost));
        uint256 supplyUnderlyingBefore = weth.totalSupply();
        uint256 totalBorrowsBefore = mWethHost.totalBorrows();

        // borrow; should fail

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.borrow(amount);

        // borrow; try again
        operator.setCollateralFactor(address(mWethHost), DEFAULT_COLLATERAL_FACTOR);
        mWethHost.borrow(amount);

        _afterBorrowChecks(
            amount, balanceUnderlyingBefore, balanceUnderlyingMTokenBefore, supplyUnderlyingBefore, totalBorrowsBefore
        );
    }

    ////////////////////////////////////////////////////////////
    //                      TotalBorrows                      //
    ////////////////////////////////////////////////////////////

    function test_unit_totalBorrows_success_afterBorrow(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // supply tokens; assure collateral factor is met
        _borrowPrerequisites(address(mWethHost), amount * 2);

        // before state
        uint256 balanceUnderlyingBefore = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenBefore = weth.balanceOf(address(mWethHost));
        uint256 supplyUnderlyingBefore = weth.totalSupply();
        uint256 totalBorrowsBefore = mWethHost.totalBorrows();

        _borrowAndCheck(
            amount, balanceUnderlyingBefore, balanceUnderlyingMTokenBefore, supplyUnderlyingBefore, totalBorrowsBefore
        );
    }

    function test_unit_totalBorrows_success_afterExtensionCall(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // supply tokens; assure collateral factor is met
        _borrowPrerequisites(address(mWethHost), amount * 2);

        // before state
        uint256 balanceUnderlyingBefore = weth.balanceOf(address(this));
        uint256 totalBorrowsBefore = mWethHost.totalBorrows();
        uint256 accountBorrowsBefore = mWethHost.borrowBalanceStored(address(this));

        mWethHost.updateAllowedChain(1, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Borrow(address(this), amount, accountBorrowsBefore + amount, totalBorrowsBefore + amount);
        vm.expectEmit(true, true, true, true);
        emit ImErc20Host.mErc20Host_BorrowOnExtensionChain(address(this), 1, amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.performExtensionCall(2, amount, 1);

        {
            // ~~~~~~~~~~ Assertions ~~~~~~~~~~
            uint256 balanceUnderlyingAfter = weth.balanceOf(address(this));
            uint256 totalBorrowsAfter = mWethHost.totalBorrows();

            assertEq(balanceUnderlyingBefore, balanceUnderlyingAfter, "1");
            assertLt(totalBorrowsBefore, totalBorrowsAfter, "2");
        }
    }

    ////////////////////////////////////////////////////////////
    //                   LiquidateExternal                    //
    ////////////////////////////////////////////////////////////

    function test_unit_liquidateExternal_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Liquidate)
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_JournalNotValid(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal("", "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_JournalIsNonEmptyButLengthIsNotValid(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal("0x", "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_AmountNotValid_whenDecodedAmountIs0() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), 0);

        (address(batchSubmitter));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_liquidate_RevertsWhen_SealVerificationFails(uint256 amount)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        verifierMock.setStatus(true); // set for failure

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_CallerNotAllowed(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        bytes memory journalData = _createAccumulatedAmountJournal(users.alice, address(mWethHost), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_CallerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_DstChainNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal = _encodeJournal(
            address(this), address(mWethHost), 1, 1, uint32(block.chainid), uint32(block.chainid + 1), true
        );
        bytes memory journalData = _wrapJournal(journal);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_DstChainNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_AddressNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal =
            _encodeJournal(address(this), address(mDaiHost), 1, 1, uint32(block.chainid), uint32(block.chainid), true);
        bytes memory journalData = _wrapJournal(journal);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_ChainNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal =
            _encodeJournal(address(this), address(mWethHost), 1, 1, uint32(block.chainid), uint32(block.chainid), true);
        bytes memory journalData = _wrapJournal(journal);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        mWethHost.updateAllowedChain(uint32(block.chainid), false);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_ChainNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_L1InclusionRequired() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal = _encodeJournal(
            address(this), address(mWethHost), 1, 1, uint32(block.chainid), uint32(block.chainid), false
        );
        bytes memory journalData = _wrapJournal(journal);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_L1InclusionRequired.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    function test_unit_liquidateExternal_revertsWith_mErc20Host_AmountTooBig() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal =
            _encodeJournal(address(this), address(mWethHost), 1, 1, uint32(block.chainid), uint32(block.chainid), true);
        bytes memory journalData = _wrapJournal(journal);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;
        address[] memory _users = new address[](1);
        _users[0] = users.alice;
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountTooBig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    struct LiquidateStateInternal {
        uint256 balanceUnderlyingBefore;
        uint256 balanceMTokenBefore;
        uint256 totalMSupplyBefore;
        uint256 totalBorrowsBefore;
        uint256 accountBorrowBefore;
        uint256 balanceUnderlyingAfter;
        uint256 balanceMTokenAfter;
        uint256 totalMSupplyAfter;
        uint256 totalBorrowsAfter;
        uint256 accountBorrowAfter;
    }

    function test_unit_liquidateExternal_revertsWith_RepayTooMuch_whenSealVerificationWasOk(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        mWethHost.setRolesOperator(address(roles));

        _repayPrerequisites(address(mWethHost), amount * 2, amount);

        _getTokens(weth, users.alice, amount * 10);
        bytes memory journalData = _createAccumulatedAmountJournal(users.bob, address(mWethHost), amount);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount / 10;
        address[] memory _users = new address[](1);
        _users[0] = address(this);
        address[] memory collaterals = new address[](1);
        collaterals[0] = address(mWethHost);

        operator.setCloseFactor(0.086e18);
        operator.setLiquidationIncentive(address(mWethHost), 1e17);

        _resetContext(users.bob);
        mWethHost.updateAllowedCallerStatus(users.alice, true);

        _resetContext(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.liquidateExternal(journalData, "0x123", _users, amounts, collaterals, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mint(amount, address(this), amount - 1000);
    }

    function test_unit_mint_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Mint)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mint(amount, address(this), amount - 1000);
    }

    function test_unit_mint_revertsWith_Operator_MarketSupplyReached_revertGiven(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);
        _whenSupplyCapIsReached(address(mWethHost), amount);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethHost), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketSupplyReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mint(amount, address(this), amount - 1000);
        // it should revert with Operator_MarketSupplyReached
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success_afterMint(uint256 amount) external whenMarketIsListed(address(mWethHost)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethHost), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));
        mWethHost.mint(amount, address(this), amount - 1000);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");

        // it should transfer underlying from user
        assertGt(balanceWethBefore, balanceWethAfter, "expected balanceWethBefore to be greater than balanceWethAfter");

        assertEq(
            totalSupplyAfter - amount,
            totalSupplyBefore,
            "expected totalSupplyAfter - amount to equal totalSupplyBefore"
        );
    }

    ////////////////////////////////////////////////////////////
    //                          Mint                          //
    ////////////////////////////////////////////////////////////

    function test_unit_mint_revertsWith_mint_GivenAmountIs0() external whenMarketIsListed(address(mWethHost)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 0;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(); //arithmetic underflow or overflow

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mint(amount, address(this), amount);
    }

    ////////////////////////////////////////////////////////////
    //                      MintExternal                      //
    ////////////////////////////////////////////////////////////

    function test_unit_mintExternal_revertsWith_mErc20Host_JournalNotValid_whenJournalEmpty(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal("", "0x123", amounts, new uint256[](1), address(this));
    }

    function test_unit_mintExternal_revertsWith_mTokenProofDecoderLib_InvalidLength_whenJournalCorrupted(uint256 amount)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        bytes[] memory journals = new bytes[](1);
        journals[0] = hex"1234";
        bytes memory journalData = abi.encode(journals);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenProofDecoderLib.mTokenProofDecoderLib_InvalidLength.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));
    }

    function test_unit_mintExternal_revertsWith_mErc20Host_AmountNotValid()
        external
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));
    }

    function test_unit_mintExternal_revertsWith_mint_RevertsWhen_SealVerificationFails(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes[] memory journals = new bytes[](1);
        journals[0] = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);
        bytes memory journalData = abi.encode(journals);

        verifierMock.setStatus(true); // set for failure

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success_afterExtensionCall_mint_WhenSealVerificationWasOk(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");

        // it should transfer underlying from user
        assertEq(balanceWethBefore, balanceWethAfter, "it should transfer underlying from user");

        assertEq(
            totalSupplyAfter - amount,
            totalSupplyBefore,
            "expected totalSupplyAfter - amount to equal totalSupplyBefore"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      MintExternal                      //
    ////////////////////////////////////////////////////////////

    function test_unit_mintExternal_revertsWith_mErc20Host_AmountTooBig_whenCallerAllowedByAdmin()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWethHost));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        mWethHost.updateAllowedCallerStatus(users.alice, true);

        bytes memory journal =
            _encodeJournal(users.bob, address(mWethHost), 1, 1, uint32(block.chainid), uint32(block.chainid), true);
        bytes memory journalData = _wrapJournal(journal);

        uint256[] memory mintAmounts = new uint256[](1);
        mintAmounts[0] = 2;
        uint256[] memory minAmountsOut = new uint256[](1);
        minAmountsOut[0] = 0;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountTooBig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", mintAmounts, minAmountsOut, users.alice);
    }

    function test_unit_mintExternal_revertsWith_mErc20Host_AmountTooBig_whenCallerIsProofForwarder()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWethHost));
        roles.allowFor(users.alice, roles.PROOF_FORWARDER(), true);

        bytes memory journal =
            _encodeJournal(users.alice, address(mWethHost), 1, 1, uint32(block.chainid), uint32(block.chainid), false);
        bytes memory journalData = _wrapJournal(journal);

        uint256[] memory mintAmounts = new uint256[](1);
        mintAmounts[0] = 2;
        uint256[] memory minAmountsOut = new uint256[](1);
        minAmountsOut[0] = 0;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountTooBig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", mintAmounts, minAmountsOut, users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                    SetReserveFactor                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setReserveFactor_success(uint256 amount) external whenMarketIsListed(address(mWethHost)) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.NewReserveFactor(mWethHost.reserveFactorMantissa(), 1e17);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.setReserveFactor(1e17);
    }

    ////////////////////////////////////////////////////////////
    //                      MintExternal                      //
    ////////////////////////////////////////////////////////////

    function test_unit_mintExternal_revertsWith_Operator_OutflowVolumeReached_whenOutflowLimitTight(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE36)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount * 20);

        Operator(operator).setOutflowTimeLimitInUSD(amount * 1e8 + 1);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        vm.warp(block.timestamp + 2 hours);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));
        vm.warp(block.timestamp + 1);
        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        vm.warp(block.timestamp + 2 hours);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success_and_OverflowLimitNotExceeded(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount * 10);

        Operator(operator).setOutflowTimeLimitInUSD(amount * 50);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");
        assertEq(
            totalSupplyAfter,
            totalSupplyBefore + 2 * amount,
            "expected totalSupplyAfter to equal totalSupplyBefore + 2 * amount"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      MintExternal                      //
    ////////////////////////////////////////////////////////////

    function test_unit_mintExternal_revertsWith_Operator_UserBlacklisted_whenSealVerificationWasOk(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount * 10);

        Operator(operator).setOutflowTimeLimitInUSD(amount * 50);
        blacklister.blacklist(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));
    }

    function test_unit_mintExternal_revertsWith_mErc20Host_AmountNotValid_whenSealVerificationWasOk()
        external
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), 0);

        Operator(operator).setOutflowTimeLimitInUSD(100);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        assertEq(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to equal balanceOfBefore");
        assertEq(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to equal totalSupplyBefore");
    }

    function test_unit_mintExternal_revertsWith_Operator_OutflowVolumeReached_whenSealVerificationWasOk(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE36)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount * 20);

        Operator(operator).setOutflowTimeLimitInUSD(amount * 1e8 * 2 - 1);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        Operator(operator).setOutflowTimeLimitInUSD(amount * 1e8 * 50);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");
    }

    function test_unit_mintExternal_revertsWith_Operator_UserNotWhitelisted_whenSealVerificationWasOk(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        operator.setWhitelistStatus(true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        operator.setWhitelistedUser(address(this), true);
        mWethHost.mintExternal(journalData, "0x123", amounts, new uint256[](1), address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfAfter, balanceOfBefore, "expected balanceOfAfter to be greater than balanceOfBefore");

        // it should increase total supply by amount
        assertGt(totalSupplyAfter, totalSupplyBefore, "expected totalSupplyAfter to be greater than totalSupplyBefore");

        // it should transfer underlying from user
        assertEq(balanceWethBefore, balanceWethAfter, "it should transfer underlying from user");

        assertEq(
            totalSupplyAfter - amount,
            totalSupplyBefore,
            "expected totalSupplyAfter - amount to equal totalSupplyBefore"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    RedeemUnderlying                    //
    ////////////////////////////////////////////////////////////

    function test_unit_redeemUnderlying_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWethHost.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith_Operator_MarketNotListed_givenMarketIsNotListed(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWethHost.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(mWethHost), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();
        mWethHost.redeem(amount);

        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.redeemUnderlying(amount);
    }

    function test_unit_redeemUnderlying_revertsWith_mt_RedeemEmpty_givenRedeemAmountsAre0()
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_RedeemEmpty.selector);
        mWethHost.redeem(0);
        vm.expectRevert(mTokenStorage.mt_RedeemEmpty.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.redeemUnderlying(0);
    }

    function test_unit_redeemUnderlying_revertsWith_mt_RedeemCashNotAvailable_whenTheMarketDoesNotHaveEnoughAssetsForTheRedeemOperation(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mt_RedeemCashNotAvailable

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);
        mWethHost.redeem(amount);

        vm.expectRevert(mTokenStorage.mt_RedeemCashNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.redeemUnderlying(amount);
    }

    ////////////////////////////////////////////////////////////
    //                         Redeem                         //
    ////////////////////////////////////////////////////////////

    function test_unit_redeem_success_redeemTokens(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _redeem(amount, false);
    }

    function test_unit_redeem_success_redeemUnderlying(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _redeem(amount, true);
    }

    ////////////////////////////////////////////////////////////
    //                  PerformExtensionCall                  //
    ////////////////////////////////////////////////////////////

    function test_unit_performExtensionCall_revertsWith_AmountNotValid_givenDecodedLiquidityIs0() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CommonLib.AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.performExtensionCall(1, 0, 1);
    }

    function test_unit_performExtensionCall_revertsWith_LiquiditySealVerificationFails(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        verifierMock.setStatus(true); // set for failure

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.performExtensionCall(1, amount, 1);
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success(uint256 amount)
        external
        whenMarketIsListed(address(mWethHost))
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _borrowPrerequisites(address(mWethHost), amount);

        amount = amount - DEFAULT_INFLATION_INCREASE;

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        mWethHost.updateAllowedChain(1, true);
        mWethHost.performExtensionCall(1, amount, 1);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertEq(balanceOfAfter + amount, balanceOfBefore, "B");

        // it should decrease total supply by amount
        assertGt(totalSupplyBefore, totalSupplyAfter, "C");
        assertEq(totalSupplyBefore - amount, totalSupplyAfter, "D");

        // it should transfer
        assertEq(balanceWethBefore, balanceWethAfter, "F");
    }

    ////////////////////////////////////////////////////////////
    //                         Repay                          //
    ////////////////////////////////////////////////////////////

    function test_unit_repay_revertsWith_Operator_Paused_revertGiven(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Repay)
        whenMarketIsListed(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repay(amount);
    }

    function test_unit_repay_revertsWith_Operator_MarketNotListed(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Repay)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repay(amount);
    }

    ////////////////////////////////////////////////////////////
    //                      TotalBorrows                      //
    ////////////////////////////////////////////////////////////

    function test_unit_totalBorrows_success_repay_GivenAmountIs0(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _repayPrerequisites(address(mWethHost), amount * 2, amount);

        uint256 totalBorrowsBefore = mWethHost.totalBorrows();

        weth.approve(address(mWethHost), amount);
        mWethHost.repay(0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 totalBorrowsAfter = mWethHost.totalBorrows();

        // state should be the same

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(totalBorrowsAfter, totalBorrowsBefore, "expected totalBorrowsAfter to equal totalBorrowsBefore");
    }

    struct RepayStateInternal {
        uint256 balanceUnderlyingBefore;
        uint256 balanceMTokenBefore;
        uint256 totalMSupplyBefore;
        uint256 totalBorrowsBefore;
        uint256 accountBorrowBefore;
        uint256 balanceUnderlyingAfter;
        uint256 balanceMTokenAfter;
        uint256 totalMSupplyAfter;
        uint256 totalBorrowsAfter;
        uint256 accountBorrowAfter;
    }

    ////////////////////////////////////////////////////////////
    //                        Overflow                        //
    ////////////////////////////////////////////////////////////

    function test_unit_overflow_revertsWith(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        {
            _repayPrerequisites(address(mWethHost), amount * 2, amount);
            _getTokens(weth, address(this), amount * 10);
            weth.approve(address(mWethHost), amount * 10);
        }

        RepayStateInternal memory vars;
        // before state
        vars.balanceUnderlyingBefore = weth.balanceOf(address(this));
        vars.balanceMTokenBefore = mWethHost.balanceOf(address(this));
        vars.totalBorrowsBefore = mWethHost.totalBorrows();
        vars.accountBorrowBefore = mWethHost.borrowBalanceStored(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(); //panic: arithmetic underflow or overflow (0x11)

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repay(amount * 10);

        mWethHost.repay(type(uint256).max);

        // after state

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        vars.balanceUnderlyingAfter = weth.balanceOf(address(this));
        vars.balanceMTokenAfter = mWethHost.balanceOf(address(this));
        vars.totalBorrowsAfter = mWethHost.totalBorrows();
        vars.accountBorrowAfter = mWethHost.borrowBalanceStored(address(this));

        {
            // it should use only the amount borrowed
            assertEq(
                vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter,
                amount,
                "expected vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter to equal amount"
            );

            // it should have same mToken balance
            assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter, "it should have same mToken balance");

            // it should decrease totalBorrows
            assertGt(
                vars.totalBorrowsBefore,
                vars.totalBorrowsAfter,
                "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
            );

            // it should decrease accountBorrows
            assertGt(
                vars.accountBorrowBefore,
                vars.accountBorrowAfter,
                "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
            );
        }
    }

    ////////////////////////////////////////////////////////////
    //                  BorrowBalanceStored                   //
    ////////////////////////////////////////////////////////////

    function test_unit_borrowBalanceStored_success(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Repay)
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Borrow)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        RepayStateInternal memory vars;

        _repayPrerequisites(address(mWethHost), amount * 2, amount);

        uint256 repayAmount = amount / 10;
        weth.approve(address(mWethHost), repayAmount);

        // before state
        vars.balanceUnderlyingBefore = weth.balanceOf(address(this));
        vars.balanceMTokenBefore = mWethHost.balanceOf(address(this));
        vars.totalMSupplyBefore = mWethHost.totalSupply();
        vars.totalBorrowsBefore = mWethHost.totalBorrows();
        vars.accountBorrowBefore = mWethHost.borrowBalanceStored(address(this));

        mWethHost.repay(repayAmount);

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(address(this));
        vars.balanceMTokenAfter = mWethHost.balanceOf(address(this));
        vars.totalMSupplyAfter = mWethHost.totalSupply();
        vars.totalBorrowsAfter = mWethHost.totalBorrows();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vars.accountBorrowAfter = mWethHost.borrowBalanceStored(address(this));

        // it should use only the amount borrowed

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter,
            repayAmount,
            "expected vars.balanceUnderlyingBefore - vars.balanceUnderlyingAfter to equal repayAmount"
        );

        // it should have same mToken balance
        assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter, "it should have same mToken balance");

        // it should decrease totalBorrows
        assertGt(
            vars.totalBorrowsBefore,
            vars.totalBorrowsAfter,
            "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
        );
        assertGt(vars.totalBorrowsAfter, 0, "expected vars.totalBorrowsAfter to be greater than 0");

        // it should decrease accountBorrows
        assertGt(
            vars.accountBorrowBefore,
            vars.accountBorrowAfter,
            "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
        );
        assertGt(vars.accountBorrowAfter, 0, "expected vars.accountBorrowAfter to be greater than 0");
    }

    ////////////////////////////////////////////////////////////
    //                     RepayExternal                      //
    ////////////////////////////////////////////////////////////

    function test_unit_repayExternal_revertsWith_mErc20Host_AmountTooBig()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        operator.supportMarket(address(mWethHost));
        operator.setCollateralFactor(address(mWethHost), DEFAULT_COLLATERAL_FACTOR);
        {
            address[] memory markets = new address[](1);
            markets[0] = address(mWethHost);
            operator.enterMarkets(markets);
        }

        uint256 supplyAmount = 100 ether;
        uint256 borrowAmount = 10 ether;
        _getTokens(weth, address(this), supplyAmount);
        weth.approve(address(mWethHost), supplyAmount);
        mWethHost.mint(supplyAmount, address(this), 0);
        mWethHost.borrow(borrowAmount);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), 1);
        uint256[] memory repayAmounts = new uint256[](1);
        repayAmounts[0] = borrowAmount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountTooBig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repayExternal(journalData, "0x123", repayAmounts, address(this));
    }

    function test_unit_repayExternal_revertsWith_mErc20Host_JournalNotValid_whenJournalEmpty(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repayExternal("", "0x123", amounts, address(this));
    }

    function test_unit_repayExternal_revertsWith_mTokenProofDecoderLib_InvalidLength_whenJournalCorrupted(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        bytes[] memory journals = new bytes[](1);
        journals[0] = hex"1234";
        bytes memory journalData = abi.encode(journals);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenProofDecoderLib.mTokenProofDecoderLib_InvalidLength.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repayExternal(journalData, "0x123", amounts, address(this));
    }

    function test_unit_repayExternal_revertsWith_mErc20Host_AmountNotValid()
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repayExternal(journalData, "0x123", amounts, address(this));
    }

    function test_unit_repayExternal_revertsWith_repay_RevertsWhen_SealVerificationFails(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        verifierMock.setStatus(true); // set for failure

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethHost.repayExternal(journalData, "0x123", amounts, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                  BorrowBalanceStored                   //
    ////////////////////////////////////////////////////////////

    function test_unit_borrowBalanceStored_success_repay_WhenSealVerificationWasOk(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        RepayStateInternal memory vars;

        _repayPrerequisites(address(mWethHost), amount * 2, amount);

        // before state
        vars.balanceUnderlyingBefore = weth.balanceOf(address(this));
        vars.balanceMTokenBefore = mWethHost.balanceOf(address(this));
        vars.totalBorrowsBefore = mWethHost.totalBorrows();
        vars.accountBorrowBefore = mWethHost.borrowBalanceStored(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        mWethHost.repayExternal(journalData, "0x123", amounts, address(this));

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(address(this));
        vars.balanceMTokenAfter = mWethHost.balanceOf(address(this));
        vars.totalBorrowsAfter = mWethHost.totalBorrows();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vars.accountBorrowAfter = mWethHost.borrowBalanceStored(address(this));

        // it should not use tokens

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            vars.balanceUnderlyingBefore,
            vars.balanceUnderlyingAfter,
            "expected vars.balanceUnderlyingBefore to equal vars.balanceUnderlyingAfter"
        );

        // it should have same mToken balance
        assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter, "it should have same mToken balance");

        // it should decrease totalBorrows
        assertGt(
            vars.totalBorrowsBefore,
            vars.totalBorrowsAfter,
            "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
        );
        assertEq(vars.totalBorrowsAfter, 0, "expected vars.totalBorrowsAfter to equal 0");

        // it should decrease accountBorrows
        assertGt(
            vars.accountBorrowBefore,
            vars.accountBorrowAfter,
            "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
        );
        assertEq(vars.accountBorrowAfter, 0, "expected vars.accountBorrowAfter to equal 0");
    }

    function test_unit_borrowBalanceStored_success_andRepayingMax(uint256 amount)
        external
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenMarketIsListed(address(mWethHost))
        whenMarketEntered(address(mWethHost))
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        RepayStateInternal memory vars;

        _repayPrerequisites(address(mWethHost), amount * 2, amount);

        // before state
        vars.balanceUnderlyingBefore = weth.balanceOf(address(this));
        vars.balanceMTokenBefore = mWethHost.balanceOf(address(this));
        vars.totalBorrowsBefore = mWethHost.totalBorrows();
        vars.accountBorrowBefore = mWethHost.borrowBalanceStored(address(this));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = type(uint256).max;

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethHost), amount);

        mWethHost.repayExternal(journalData, "0x123", amounts, address(this));

        // after state
        vars.balanceUnderlyingAfter = weth.balanceOf(address(this));
        vars.balanceMTokenAfter = mWethHost.balanceOf(address(this));
        vars.totalBorrowsAfter = mWethHost.totalBorrows();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vars.accountBorrowAfter = mWethHost.borrowBalanceStored(address(this));

        // it should not use tokens

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            vars.balanceUnderlyingBefore,
            vars.balanceUnderlyingAfter,
            "expected vars.balanceUnderlyingBefore to equal vars.balanceUnderlyingAfter"
        );

        // it should have same mToken balance
        assertEq(vars.balanceMTokenBefore, vars.balanceMTokenAfter, "it should have same mToken balance");

        // it should decrease totalBorrows
        assertGt(
            vars.totalBorrowsBefore,
            vars.totalBorrowsAfter,
            "expected vars.totalBorrowsBefore to be greater than vars.totalBorrowsAfter"
        );
        assertEq(vars.totalBorrowsAfter, 0, "expected vars.totalBorrowsAfter to equal 0");

        // it should decrease accountBorrows
        assertGt(
            vars.accountBorrowBefore,
            vars.accountBorrowAfter,
            "expected vars.accountBorrowBefore to be greater than vars.accountBorrowAfter"
        );
        assertEq(vars.accountBorrowAfter, 0, "expected vars.accountBorrowAfter to equal 0");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

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

    function _buildLiquidateExternalArgs(uint256 repayAmount, uint32 chainId)
        internal
        view
        returns (LiquidateExternalArgs memory args)
    {
        bytes memory journal =
            abi.encodePacked(address(this), address(mWethHost), repayAmount, repayAmount, chainId, chainId, true);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;
        args.journalData = abi.encode(journals);

        args.userToLiquidate = new address[](1);
        args.userToLiquidate[0] = users.bob;

        args.liquidateAmount = new uint256[](1);
        args.liquidateAmount[0] = repayAmount;

        args.collateral = new address[](1);
        args.collateral[0] = address(0);
    }

    // stack too deep
    function _borrowAndCheck(
        uint256 amount,
        uint256 balanceUnderlyingBefore,
        uint256 balanceUnderlyingMTokenBefore,
        uint256 supplyUnderlyingBefore,
        uint256 totalBorrowsBefore
    ) private {
        uint256 accountBorrowsBefore = mWethHost.borrowBalanceStored(address(this));

        // borrow

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Borrow(address(this), amount, accountBorrowsBefore + amount, totalBorrowsBefore + amount);
        mWethHost.borrow(amount);

        _afterBorrowChecks(
            amount, balanceUnderlyingBefore, balanceUnderlyingMTokenBefore, supplyUnderlyingBefore, totalBorrowsBefore
        );
    }

    function _afterBorrowChecks(
        uint256 amount,
        uint256 balanceUnderlyingBefore,
        uint256 balanceUnderlyingMTokenBefore,
        uint256 supplyUnderlyingBefore,
        uint256 totalBorrowsBefore
    ) private view {
        // after state
        bool memberAfter = operator.checkMembership(address(this), address(mWethHost));
        uint256 balanceUnderlyingAfter = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenAfter = weth.balanceOf(address(mWethHost));
        uint256 supplyUnderlyingAfter = weth.totalSupply();
        uint256 totalBorrowsAfter = mWethHost.totalBorrows();

        // it shoud activate ther market for sender
        assertTrue(memberAfter, "expected condition to be true: memberAfter");

        // it should transfer underlying token to sender
        assertGt(
            balanceUnderlyingAfter,
            balanceUnderlyingBefore,
            "expected balanceUnderlyingAfter to be greater than balanceUnderlyingBefore"
        );
        assertEq(
            balanceUnderlyingAfter - amount,
            balanceUnderlyingBefore,
            "expected balanceUnderlyingAfter - amount to equal balanceUnderlyingBefore"
        );

        // it should not modify underlying supply
        assertEq(supplyUnderlyingBefore, supplyUnderlyingAfter, "it should not modify underlying supply");

        // it should decrease balance of underlying from mToken
        assertGt(
            balanceUnderlyingMTokenBefore,
            balanceUnderlyingMTokenAfter,
            "expected balanceUnderlyingMTokenBefore to be greater than balanceUnderlyingMTokenAfter"
        );

        // it should increase totalBorrows
        assertGt(
            totalBorrowsAfter, totalBorrowsBefore, "expected totalBorrowsAfter to be greater than totalBorrowsBefore"
        );
    }

    function _encodeJournal(
        address sender,
        address market,
        uint256 accAmountIn,
        uint256 accAmountOut,
        uint32 chainId,
        uint32 dstChainId,
        bool l1Inclusion
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(sender, market, accAmountIn, accAmountOut, chainId, dstChainId, l1Inclusion);
    }

    function _wrapJournal(bytes memory journal) internal pure returns (bytes memory) {
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;
        return abi.encode(journals);
    }

    function _redeem(uint256 amount, bool underlying) private {
        _borrowPrerequisites(address(mWethHost), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 supplyMTokenBefore = mWethHost.totalSupply();
        uint256 balanceMTokenBefore = mWethHost.balanceOf(address(this));

        amount = amount - DEFAULT_INFLATION_INCREASE;
        uint256 exchangeRate = mWethHost.exchangeRateStored();
        uint256 redeemTokens = underlying ? (amount * EXP_SCALE) / exchangeRate : amount;
        uint256 redeemAmount = underlying ? amount : (exchangeRate * amount) / EXP_SCALE;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Transfer(address(this), address(mWethHost), redeemTokens);
        vm.expectEmit(true, true, true, true);
        emit mTokenStorage.Redeem(address(this), redeemAmount, redeemTokens);

        if (underlying) mWethHost.redeemUnderlying(amount);
        else mWethHost.redeem(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 supplyMTokenAfter = mWethHost.totalSupply();
        uint256 balanceMTokenAfter = mWethHost.balanceOf(address(this));

        // it should transfer underlying to redeemer
        assertEq(balanceWethBefore + amount, balanceWethAfter, "it should transfer underlying to redeemer");

        // it should decrease totalSupply of mToken
        assertGt(
            supplyMTokenBefore, supplyMTokenAfter, "expected supplyMTokenBefore to be greater than supplyMTokenAfter"
        );
        assertEq(
            supplyMTokenBefore - amount,
            supplyMTokenAfter,
            "expected supplyMTokenBefore - amount to equal supplyMTokenAfter"
        );

        // it should decrease redeemer balance of mToken
        assertGt(
            balanceMTokenBefore,
            balanceMTokenAfter,
            "expected balanceMTokenBefore to be greater than balanceMTokenAfter"
        );
        assertEq(
            balanceMTokenBefore - amount,
            balanceMTokenAfter,
            "expected balanceMTokenBefore - amount to equal balanceMTokenAfter"
        );
    }
}
