// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";

contract mTokenGatewayTest is BaseMTokenTest {
    bytes4 internal constant LINEA_MINT_SELECTOR = ImErc20Host.mintExternal.selector;

    address internal borrower;
    address internal receiver;
    address internal otherUser;

    function setUp() public override {
        super.setUp();

        vm.chainId(LINEA_CHAIN_ID);
        borrower = users.alice;
        receiver = users.bob;
        otherUser = users.carol;
    }

    ////////////////////////////////////////////////////////////
    //                    FirewallRegister                    //
    ////////////////////////////////////////////////////////////

    function test_unit_firewallRegister_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockFirewall firewall = new MockFirewall();

        mWethExtension.initFirewall(address(firewall));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.firewallRegister(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(firewall.registerCount(), 1, "expected firewall.registerCount() to equal 1");
        assertEq(firewall.lastRegistered(), users.alice, "expected firewall.lastRegistered() to equal users.alice");
    }

    ////////////////////////////////////////////////////////////
    //                     SetBlacklister                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setBlacklister_success() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.setBlacklister(address(blacklister));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(mWethExtension.blacklistOperator()),
            address(blacklister),
            "expected address(mWethExtension.blacklistOperator()) to equal address(blacklister)"
        );
    }

    function test_unit_setBlacklister_revertsWith_mTokenGateway_AddressNotValid_revertsWhenZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.setBlacklister(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                    EnableWhitelist                     //
    ////////////////////////////////////////////////////////////

    function test_unit_enableWhitelist_success() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_WhitelistEnabled();
        mWethExtension.enableWhitelist();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            mWethExtension.whitelistEnabled(), "expected condition to be true: mWethExtension.whitelistEnabled()"
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_WhitelistDisabled();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.disableWhitelist();
        assertFalse(
            mWethExtension.whitelistEnabled(), "expected condition to be false: mWethExtension.whitelistEnabled()"
        );
    }

    ////////////////////////////////////////////////////////////
    //                       SetPaused                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setPaused_success() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_PausedState(ImTokenOperationTypes.OperationType.AmountIn, true);
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn),
            "expected condition to be true: mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn)"
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_PausedState(ImTokenOperationTypes.OperationType.AmountIn, false);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, false);
        assertFalse(
            mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn),
            "expected condition to be false: mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn)"
        );
    }

    function test_unit_setPaused_revertsWith_mTokenGateway_CallerNotAllowed_revertsWhenNonOwner() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
    }

    function test_unit_setPaused_revertsWith_mTokenGateway_CallerNotAllowed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
        roles.allowFor(users.bob, roles.GUARDIAN_PAUSE(), true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, false);
    }

    ////////////////////////////////////////////////////////////
    //                 ExtractForRebalancing                  //
    ////////////////////////////////////////////////////////////

    function test_fuzz_extractForRebalancing_success(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);
        _getTokens(weth, address(mWethExtension), amount);
        roles.allowFor(users.alice, roles.REBALANCER(), true);

        uint256 balanceBefore = weth.balanceOf(users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWethExtension.extractForRebalancing(amount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            weth.balanceOf(users.alice),
            balanceBefore + amount,
            "expected weth.balanceOf(users.alice) to equal balanceBefore + amount"
        );
    }

    function test_unit_extractForRebalancing_revertsWith_mTokenGateway_Paused_revertsWhenPaused() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.Rebalancing, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(
            abi.encodeWithSelector(
                ImTokenGateway.mTokenGateway_Paused.selector, ImTokenOperationTypes.OperationType.Rebalancing
            )
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.extractForRebalancing(1);
    }

    function test_unit_extractForRebalancing_revertsWith_mTokenGateway_NotRebalancer_revertsWhenNotRebalancer()
        external
    {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_NotRebalancer.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.extractForRebalancing(1);
    }

    ////////////////////////////////////////////////////////////
    //                        Payable                         //
    ////////////////////////////////////////////////////////////

    function test_unit_payable_success_byOwner() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.deal(address(mWethExtension), 1 ether);
        uint256 receiverBalanceBefore = users.alice.balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.withdrawGasFees(payable(users.alice));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(mWethExtension).balance, 0, "expected address(mWethExtension).balance to equal 0");
        assertEq(
            users.alice.balance,
            receiverBalanceBefore + 1 ether,
            "expected users.alice.balance to equal receiverBalanceBefore + 1 ether"
        );
    }

    function test_unit_payable_success_bySequencer() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.deal(address(mWethExtension), 1 ether);
        roles.allowFor(users.bob, roles.SEQUENCER(), true);

        uint256 receiverBalanceBefore = users.bob.balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        mWethExtension.withdrawGasFees(payable(users.bob));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(mWethExtension).balance, 0, "expected address(mWethExtension).balance to equal 0");
        assertEq(
            users.bob.balance,
            receiverBalanceBefore + 1 ether,
            "expected users.bob.balance to equal receiverBalanceBefore + 1 ether"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    WithdrawGasFees                     //
    ////////////////////////////////////////////////////////////

    function test_unit_withdrawGasFees_revertsWith_mTokenGateway_CallerNotAllowed_revertsWhenUnauthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        mWethExtension.withdrawGasFees(payable(users.alice));
    }

    function test_unit_withdrawGasFees_revertsWith_mTokenGateway_AddressNotValid_revertsWhenReceiverZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.withdrawGasFees(payable(address(0)));
    }

    ////////////////////////////////////////////////////////////
    //                    UpdateZkVerifier                    //
    ////////////////////////////////////////////////////////////

    function test_unit_updateZkVerifier_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.ZkVerifierUpdated(address(zkVerifier), address(newVerifier));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.updateZkVerifier(address(newVerifier));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(mWethExtension.verifier()),
            address(newVerifier),
            "expected address(mWethExtension.verifier()) to equal address(newVerifier)"
        );
    }

    function test_unit_updateZkVerifier_revertsWith_mTokenGateway_AddressNotValid_revertsWhenZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.updateZkVerifier(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                      GetProofData                      //
    ////////////////////////////////////////////////////////////

    function test_unit_getProofData_success() external view {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 amountIn, uint256 amountOut) = mWethExtension.getProofData(users.alice, 0);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(amountIn, 0, "expected amountIn to equal 0");
        assertEq(amountOut, 0, "expected amountOut to equal 0");
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_mTokenGateway_AddressNotValid_whenRolesZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(0), address(blacklister), address(zkVerifier));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mTokenGateway_AddressNotValid_whenZkVerifierZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(roles), address(blacklister), address(0));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mTokenGateway_AddressNotValid_whenBlacklisterZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(roles), address(0), address(zkVerifier));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_unit_constructor_revertsWith_mTokenGateway_AddressNotValid_whenUnderlyingZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(0), address(roles), address(blacklister), address(zkVerifier));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    ////////////////////////////////////////////////////////////
    //                       Liquidate                        //
    ////////////////////////////////////////////////////////////

    function test_unit_liquidate_revertsWith_mTokenGateway_AmountNotValid() external {
        // it should revert

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, 0, address(mWethHost), address(this));
    }

    function test_unit_liquidate_revertsWith_liquidate_RevertsWhen_MarketPaused(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.Liquidate, true);

        // it should revert

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(
            abi.encodeWithSelector(
                ImTokenGateway.mTokenGateway_Paused.selector, ImTokenOperationTypes.OperationType.Liquidate
            )
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    function test_unit_liquidate_revertsWith_AmountInPaused(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // it should revert

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(
            abi.encodeWithSelector(
                ImTokenGateway.mTokenGateway_Paused.selector, ImTokenOperationTypes.OperationType.AmountIn
            )
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    function test_unit_liquidate_revertsWith_liquidate_RevertGiven_UserHasNotEnoughBalance(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        weth.approve(address(mWethExtension), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                         Uint32                         //
    ////////////////////////////////////////////////////////////

    function test_unit_liquidate_success_withPayoutReceiver_givenUserHasEnoughBalance(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), address(this), amount, uint32(block.chainid), LINEA_CHAIN_ID, borrower, address(mWethHost)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(
            balanceWethAfter + amount,
            balanceWethBefore,
            "expected balanceWethAfter + amount to equal balanceWethBefore"
        );

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore, "expected accAmountInAfter to be greater than accAmountInBefore");
    }

    ////////////////////////////////////////////////////////////
    //                       Liquidate                        //
    ////////////////////////////////////////////////////////////

    function test_unit_liquidate_revertsWith_mTokenGateway_UserBlacklisted(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    function test_unit_liquidate_revertsWith_mTokenGateway_UserBlacklisted_givenUserHasEnoughBalance(uint256 amount)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(receiver); // Blacklist receiver

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, amount, address(mWethHost), receiver);
    }

    ////////////////////////////////////////////////////////////
    //                         Uint32                         //
    ////////////////////////////////////////////////////////////

    function test_unit_liquidate_revertsWith_mTokenGateway_UserNotWhitelisted(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);

        mWethExtension.enableWhitelist();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));

        mWethExtension.setWhitelistedUser(address(this), false);
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));

        mWethExtension.setWhitelistedUser(address(this), true);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), address(this), amount, uint32(block.chainid), LINEA_CHAIN_ID, borrower, address(mWethHost)
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(
            balanceWethAfter + amount,
            balanceWethBefore,
            "expected balanceWethAfter + amount to equal balanceWethBefore"
        );

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore, "expected accAmountInAfter to be greater than accAmountInBefore");
    }

    function test_fuzz_liquidate_success_withPayoutReceiver(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);
        address userToLiquidate = otherUser;
        address collateral = address(mDaiHost);
        address payoutReceiver = receiver;

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), payoutReceiver, amount, uint32(block.chainid), LINEA_CHAIN_ID, userToLiquidate, collateral
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.liquidate(userToLiquidate, amount, collateral, payoutReceiver);

        // Verify accAmountIn increased for the receiver

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            mWethExtension.accAmountIn(payoutReceiver),
            amount,
            "expected mWethExtension.accAmountIn(payoutReceiver) to equal amount"
        );
    }

    function test_fuzz_liquidate_success_withGasFee(uint256 amount, uint256 gasFee) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);
        gasFee = bound(gasFee, 1, 1 ether);

        mWethExtension.setGasFee(gasFee);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), address(this), amount, uint32(block.chainid), LINEA_CHAIN_ID, borrower, address(mWethHost)
        );

        mWethExtension.liquidate{value: gasFee}(borrower, amount, address(mWethHost), address(this));

        // Verify the gas fee was received

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(mWethExtension).balance, gasFee, "expected address(mWethExtension).balance to equal gasFee");
    }

    ////////////////////////////////////////////////////////////
    //                        Approve                         //
    ////////////////////////////////////////////////////////////

    function test_unit_approve_revertsWith_mTokenGateway_NotEnoughGasFee() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 1 ether;
        uint256 gasFee = 0.01 ether;

        mWethExtension.setGasFee(gasFee);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_NotEnoughGasFee.selector);
        mWethExtension.liquidate{value: gasFee - 0.001 ether}(borrower, amount, address(mWethHost), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                        OutHere                         //
    ////////////////////////////////////////////////////////////

    function test_unit_outHere_revertsWith_IsPaused_revertGiven(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountOutHere, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(
            abi.encodeWithSelector(
                ImTokenGateway.mTokenGateway_Paused.selector, ImTokenOperationTypes.OperationType.AmountOutHere
            )
        );
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere("", "0x123", amounts, address(this));
    }

    modifier givenMarketIsNotPaused() {
        _;
    }

    function test_unit_outHere_revertsWith_mTokenGateway_AmountNotValid(uint256 amount)
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_AmountTooBig_whenAccumulatedAmountReceivedOrLessThanNeeded(uint256 amount)
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mTokenGateway_AmountTooBig
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount - 1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountTooBig.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_ReleaseCashNotAvailable_whenMarketDoesNotHaveLiquidity(uint256 amount)
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mTokenGateway_ReleaseCashNotAvailable
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_ReleaseCashNotAvailable.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_CallerNotAllowed(uint256 amount)
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);
        _resetContext(users.alice);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_JournalNotValid() external givenMarketIsNotPaused {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_JournalNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere("", "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_LengthNotValid() external givenMarketIsNotPaused {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal =
            _encodeJournal(address(this), address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), true);
        bytes[] memory journals = new bytes[](2);
        journals[0] = journal;
        journals[1] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_LengthNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_UserBlacklisted_whenCallerBlacklisted()
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        blacklister.blacklist(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere("", "0x123", new uint256[](0), address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_UserBlacklisted_whenReceiverBlacklisted()
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        blacklister.blacklist(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere("", "0x123", new uint256[](0), users.alice);
    }

    function test_unit_outHere_revertsWith_mTokenGateway_UserBlacklisted_whenJournalSenderBlacklisted()
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        blacklister.blacklist(users.alice);

        bytes memory journal =
            _encodeJournal(users.alice, address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), true);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_ChainNotValid_whenSourceChainInvalid()
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal = _encodeJournal(
            address(this), address(mWethExtension), 1, 1, uint32(LINEA_CHAIN_ID + 1), uint32(block.chainid), true
        );
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_ChainNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_ChainNotValid_whenDestinationChainInvalid()
        external
        givenMarketIsNotPaused
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal = _encodeJournal(
            address(this), address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid + 1), true
        );
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_ChainNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unit_outHere_revertsWith_mTokenGateway_L1InclusionRequired() external givenMarketIsNotPaused {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory journal =
            _encodeJournal(address(this), address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), false);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_L1InclusionRequired.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                       BalanceOf                        //
    ////////////////////////////////////////////////////////////

    function test_unit_balanceOf_success_whenCallerIsSender(uint256 amount) external givenMarketIsNotPaused {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);

        _getTokens(weth, address(mWethExtension), amount);

        uint256 balanceUserBefore = weth.balanceOf(address(this));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceUserAfter = weth.balanceOf(address(this));

        // it should increase accAmountOut
        assertEq(
            mWethExtension.accAmountOut(address(this)),
            amount,
            "expected mWethExtension.accAmountOut(address(this)) to equal amount"
        );

        // it should transfer underlying to user
        assertEq(balanceUserBefore + amount, balanceUserAfter, "it should transfer underlying to user");
    }

    function test_unit_balanceOf_success_whenCallerIsAllowed(uint256 amount) external givenMarketIsNotPaused {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        vm.chainId(LINEA_CHAIN_ID);
        address[] memory allowerdCallers = new address[](1);
        allowerdCallers[0] = users.alice;
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);

        _getTokens(weth, address(mWethExtension), amount);

        uint256 balanceUserBefore = weth.balanceOf(address(this));
        mWethExtension.updateAllowedCallerStatus(users.alice, true);
        _resetContext(users.alice);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceUserAfter = weth.balanceOf(address(this));

        // it should increase accAmountOut
        assertEq(
            mWethExtension.accAmountOut(address(this)),
            amount,
            "expected mWethExtension.accAmountOut(address(this)) to equal amount"
        );

        // it should transfer underlying to user
        assertEq(balanceUserBefore + amount, balanceUserAfter, "it should transfer underlying to user");
    }

    ////////////////////////////////////////////////////////////
    //                      SupplyOnHost                      //
    ////////////////////////////////////////////////////////////

    function test_unit_supplyOnHost_revertsWith_mTokenGateway_AmountNotValid() external {
        // it should revert

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.supplyOnHost(0, address(this), LINEA_MINT_SELECTOR);
    }

    function test_unit_supplyOnHost_revertsWith_supplyOnHost_RevertsWhen_MarketPaused(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // it should revert

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(
            abi.encodeWithSelector(
                ImTokenGateway.mTokenGateway_Paused.selector, ImTokenOperationTypes.OperationType.AmountIn
            )
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);
    }

    function test_unit_supplyOnHost_revertsWith_supplyOnHost_RevertGiven_UserHasNotEnoughBalance(uint256 amount)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        weth.approve(address(mWethExtension), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);
    }

    ////////////////////////////////////////////////////////////
    //                      AccAmountIn                       //
    ////////////////////////////////////////////////////////////

    function test_unit_accAmountIn_success_supplyOnHost_GivenUserHasEnoughBalance(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        uint256 balanceWethAfter = weth.balanceOf(address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            balanceWethAfter + amount,
            balanceWethBefore,
            "expected balanceWethAfter + amount to equal balanceWethBefore"
        );

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore, "expected accAmountInAfter to be greater than accAmountInBefore");
    }

    ////////////////////////////////////////////////////////////
    //                      SupplyOnHost                      //
    ////////////////////////////////////////////////////////////

    function test_unit_supplyOnHost_revertsWith_mTokenGateway_UserBlacklisted(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);
    }

    function test_unit_supplyOnHost_revertsWith_mTokenGateway_UserBlacklisted_givenUserHasEnoughBalance(uint256 amount)
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.supplyOnHost(amount, users.alice, LINEA_MINT_SELECTOR);
    }

    function test_unit_supplyOnHost_revertsWith_mTokenGateway_UserNotWhitelisted(uint256 amount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);

        mWethExtension.enableWhitelist();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        mWethExtension.setWhitelistedUser(address(this), false);
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        mWethExtension.setWhitelistedUser(address(this), true);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(
            balanceWethAfter + amount,
            balanceWethBefore,
            "expected balanceWethAfter + amount to equal balanceWethBefore"
        );

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore, "expected accAmountInAfter to be greater than accAmountInBefore");
    }

    ////////////////////////////////////////////////////////////
    //                      AccAmountIn                       //
    ////////////////////////////////////////////////////////////

    function test_unit_accAmountIn_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        WrapAndSupply wrapAndSupply = new WrapAndSupply(address(weth));
        vm.label(address(wrapAndSupply), "WrapAndSupply Helper");

        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));
        wrapAndSupply.wrapAndSupplyOnExtensionMarket{value: SMALL}(
            address(mWethExtension), address(this), LINEA_MINT_SELECTOR
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should increase accAmount

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(accAmountInAfter, accAmountInBefore, "expected accAmountInAfter to be greater than accAmountInBefore");
    }

    function test_fuzz_setGasFee_success(uint256 gasFee) external {
        gasFee = bound(gasFee, 0, 10 ether);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_GasFeeUpdated(gasFee);

        mWethExtension.setGasFee(gasFee);

        assertEq(mWethExtension.gasFee(), gasFee, "expected mWethExtension.gasFee() to equal gasFee");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

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

    function _wrapJournals(bytes[] memory journals) internal pure returns (bytes memory) {
        return abi.encode(journals);
    }
}
