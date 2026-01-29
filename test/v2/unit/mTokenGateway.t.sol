// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WrapAndSupply} from "src/utils/WrapAndSupply.sol";

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

    ////////////////////////////////////////////////////////////
    //                 InitFirewallAndRegister                  //
    ////////////////////////////////////////////////////////////

    function test_unitInitFirewallAndRegister_success() external {
        MockFirewall firewall = new MockFirewall();

        mWethExtension.initFirewall(address(firewall));
        mWethExtension.firewallRegister(users.alice);

        assertEq(firewall.registerCount(), 1);
        assertEq(firewall.lastRegistered(), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                  SetBlacklisterUpdates                   //
    ////////////////////////////////////////////////////////////

    function test_unitSetBlacklisterUpdates_success() external {
        mWethExtension.setBlacklister(address(blacklister));
        assertEq(address(mWethExtension.blacklistOperator()), address(blacklister));
    }

    ////////////////////////////////////////////////////////////
    //               SetBlacklisterRevertWhenZero               //
    ////////////////////////////////////////////////////////////

    function test_unitSetBlacklisterRevertWhenZero_revertsWith() external {
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.setBlacklister(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     DisableWhitelist                     //
    ////////////////////////////////////////////////////////////

    function test_unitDisableWhitelist_success() external {
        mWethExtension.enableWhitelist();
        assertTrue(mWethExtension.whitelistEnabled());

        mWethExtension.disableWhitelist();
        assertFalse(mWethExtension.whitelistEnabled());
    }

    ////////////////////////////////////////////////////////////
    //                 SetPausedUnpauseAsOwner                  //
    ////////////////////////////////////////////////////////////

    function test_unitSetPausedUnpauseAsOwner_success() external {
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
        assertTrue(mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn));

        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, false);
        assertFalse(mWethExtension.paused(ImTokenOperationTypes.OperationType.AmountIn));
    }

    ////////////////////////////////////////////////////////////
    //               SetPausedRevertWhenNonOwner                //
    ////////////////////////////////////////////////////////////

    function test_unitSetPausedRevertWhenNonOwner_revertsWith() external {
        vm.prank(users.alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
    }

    ////////////////////////////////////////////////////////////
    //            UnpauseRevertWhenGuardianNotOwner             //
    ////////////////////////////////////////////////////////////

    function test_unitUnpauseRevertWhenGuardianNotOwner_revertsWith() external {
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);
        roles.allowFor(users.bob, roles.GUARDIAN_PAUSE(), true);

        vm.prank(users.bob);
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.AmountIn, false);
    }

    ////////////////////////////////////////////////////////////
    //         ExtractForRebalancingTransfersUnderlying         //
    ////////////////////////////////////////////////////////////

    function test_unitExtractForRebalancingTransfersUnderlying_success() external {
        uint256 amount = 1 ether;
        _getTokens(weth, address(mWethExtension), amount);
        roles.allowFor(users.alice, roles.REBALANCER(), true);

        uint256 balanceBefore = weth.balanceOf(users.alice);
        vm.prank(users.alice);
        mWethExtension.extractForRebalancing(amount);

        assertEq(weth.balanceOf(users.alice), balanceBefore + amount);
    }

    ////////////////////////////////////////////////////////////
    //          ExtractForRebalancingRevertWhenPaused           //
    ////////////////////////////////////////////////////////////

    function test_unitExtractForRebalancingRevertWhenPaused_revertsWith() external {
        mWethExtension.setPaused(ImTokenOperationTypes.OperationType.Rebalancing, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                ImTokenGateway.mTokenGateway_Paused.selector, ImTokenOperationTypes.OperationType.Rebalancing
            )
        );
        mWethExtension.extractForRebalancing(1);
    }

    ////////////////////////////////////////////////////////////
    //       ExtractForRebalancingRevertWhenNotRebalancer       //
    ////////////////////////////////////////////////////////////

    function test_unitExtractForRebalancingRevertWhenNotRebalancer_revertsWith() external {
        vm.prank(users.alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_NotRebalancer.selector);
        mWethExtension.extractForRebalancing(1);
    }

    ////////////////////////////////////////////////////////////
    //                  WithdrawGasFeesByOwner                  //
    ////////////////////////////////////////////////////////////

    function test_unitWithdrawGasFeesByOwner_success() external {
        vm.deal(address(mWethExtension), 1 ether);
        uint256 receiverBalanceBefore = users.alice.balance;

        mWethExtension.withdrawGasFees(payable(users.alice));

        assertEq(address(mWethExtension).balance, 0);
        assertEq(users.alice.balance, receiverBalanceBefore + 1 ether);
    }

    ////////////////////////////////////////////////////////////
    //                WithdrawGasFeesBySequencer                //
    ////////////////////////////////////////////////////////////

    function test_unitWithdrawGasFeesBySequencer_success() external {
        vm.deal(address(mWethExtension), 1 ether);
        roles.allowFor(users.bob, roles.SEQUENCER(), true);

        uint256 receiverBalanceBefore = users.bob.balance;
        vm.prank(users.bob);
        mWethExtension.withdrawGasFees(payable(users.bob));

        assertEq(address(mWethExtension).balance, 0);
        assertEq(users.bob.balance, receiverBalanceBefore + 1 ether);
    }

    ////////////////////////////////////////////////////////////
    //          WithdrawGasFeesRevertWhenUnauthorized           //
    ////////////////////////////////////////////////////////////

    function test_unitWithdrawGasFeesRevertWhenUnauthorized_revertsWith() external {
        vm.prank(users.alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.withdrawGasFees(payable(users.alice));
    }

    ////////////////////////////////////////////////////////////
    //          WithdrawGasFeesRevertWhenReceiverZero           //
    ////////////////////////////////////////////////////////////

    function test_unitWithdrawGasFeesRevertWhenReceiverZero_revertsWith() external {
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.withdrawGasFees(payable(address(0)));
    }

    ////////////////////////////////////////////////////////////
    //                 UpdateZkVerifierUpdates                  //
    ////////////////////////////////////////////////////////////

    function test_unitUpdateZkVerifierUpdates_success() external {
        ZkVerifier newVerifier = new ZkVerifier(address(this), "0x456", address(verifierMock));

        mWethExtension.updateZkVerifier(address(newVerifier));

        assertEq(address(mWethExtension.verifier()), address(newVerifier));
    }

    ////////////////////////////////////////////////////////////
    //              UpdateZkVerifierRevertWhenZero              //
    ////////////////////////////////////////////////////////////

    function test_unitUpdateZkVerifierRevertWhenZero_revertsWith() external {
        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        mWethExtension.updateZkVerifier(address(0));
    }

    ////////////////////////////////////////////////////////////
    //             GetProofDataReturnsAccumulators              //
    ////////////////////////////////////////////////////////////

    function test_unitGetProofDataReturnsAccumulators_success() external view {
        (uint256 amountIn, uint256 amountOut) = mWethExtension.getProofData(users.alice, 0);
        assertEq(amountIn, 0);
        assertEq(amountOut, 0);
    }

    ////////////////////////////////////////////////////////////
    //              InitializeRevertWhenRolesZero               //
    ////////////////////////////////////////////////////////////

    function test_unitInitializeRevertWhenRolesZero_revertsWith() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(0), address(blacklister), address(zkVerifier));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    ////////////////////////////////////////////////////////////
    //             InitializeRevertWhenVerifierZero             //
    ////////////////////////////////////////////////////////////

    function test_unitInitializeRevertWhenVerifierZero_revertsWith() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(roles), address(blacklister), address(0));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    ////////////////////////////////////////////////////////////
    //           InitializeRevertWhenBlacklisterZero            //
    ////////////////////////////////////////////////////////////

    function test_unitInitializeRevertWhenBlacklisterZero_revertsWith() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(weth), address(roles), address(0), address(zkVerifier));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    ////////////////////////////////////////////////////////////
    //            InitializeRevertWhenUnderlyingZero            //
    ////////////////////////////////////////////////////////////

    function test_unitInitializeRevertWhenUnderlyingZero_revertsWith() external {
        mTokenGateway impl = new mTokenGateway();
        bytes memory initData = _gatewayInitData(address(0), address(roles), address(blacklister), address(zkVerifier));

        vm.expectRevert(ImTokenGateway.mTokenGateway_AddressNotValid.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    ////////////////////////////////////////////////////////////
    //                      MTokenGateway                       //
    ////////////////////////////////////////////////////////////

    function test_unitMTokenGateway_revertsWith_liquidate_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.liquidate(borrower, 0, address(mWethHost), address(this));
    }

    function test_unitMTokenGateway_revertsWith_liquidate_RevertWhen_MarketPaused(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.Liquidate, true);

        // it should revert
        vm.expectRevert();
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_AmountInPaused(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // it should revert
        vm.expectRevert();
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    modifier mTokenGateway_liquidate_whenAmountGreaterThan0() {
        // @dev does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //                      MTokenGateway                       //
    ////////////////////////////////////////////////////////////

    function test_unitMTokenGateway_revertsWith_liquidate_RevertGiven_UserHasNotEnoughBalance(uint256 amount)
        external
        mTokenGateway_liquidate_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        weth.approve(address(mWethExtension), amount);
        vm.expectRevert();
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    function test_unitMTokenGateway_success_liquidate_GivenUserHasEnoughBalance(uint256 amount)
        external
        mTokenGateway_liquidate_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), address(this), amount, uint32(block.chainid), LINEA_CHAIN_ID, borrower, address(mWethHost)
        );

        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }

    function test_unitMTokenGateway_success_liquidate_GivenUserHasEnoughBalance_ButBlacklisted(uint256 amount)
        external
        mTokenGateway_liquidate_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(address(this));
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                GivenUserHasEnoughBalance                 //
    ////////////////////////////////////////////////////////////

    function test_unitGivenUserHasEnoughBalance_success_ButReceiverBlacklisted(uint256 amount)
        external
        mTokenGateway_liquidate_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(receiver); // Blacklist receiver
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.liquidate(borrower, amount, address(mWethHost), receiver);
    }

    ////////////////////////////////////////////////////////////
    //                      MTokenGateway                       //
    ////////////////////////////////////////////////////////////

    function test_unitMTokenGateway_success_liquidate_GivenUserHasEnoughBalance_ButWhitelistEnabled(uint256 amount)
        external
        mTokenGateway_liquidate_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);

        mWethExtension.enableWhitelist();

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

        mWethExtension.liquidate(borrower, amount, address(mWethHost), address(this));

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }

    ////////////////////////////////////////////////////////////
    //             LiquidateWithDifferentParameters             //
    ////////////////////////////////////////////////////////////

    function test_unitLiquidateWithDifferentParameters_success() external {
        uint256 amount = 1 ether;
        address userToLiquidate = otherUser;
        address collateral = address(mDaiHost);
        address payoutReceiver = receiver;

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), payoutReceiver, amount, uint32(block.chainid), LINEA_CHAIN_ID, userToLiquidate, collateral
        );

        mWethExtension.liquidate(userToLiquidate, amount, collateral, payoutReceiver);

        // Verify accAmountIn increased for the receiver
        assertEq(mWethExtension.accAmountIn(payoutReceiver), amount);
    }

    ////////////////////////////////////////////////////////////
    //                   LiquidateWithGasFee                    //
    ////////////////////////////////////////////////////////////

    function test_unitLiquidateWithGasFee_success() external {
        uint256 amount = 1 ether;
        uint256 gasFee = 0.01 ether;

        mWethExtension.setGasFee(gasFee);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        vm.expectEmit(true, true, true, true);
        emit ImTokenGateway.mTokenGateway_Liquidate(
            address(this), address(this), amount, uint32(block.chainid), LINEA_CHAIN_ID, borrower, address(mWethHost)
        );

        mWethExtension.liquidate{value: gasFee}(borrower, amount, address(mWethHost), address(this));

        // Verify the gas fee was received
        assertEq(address(mWethExtension).balance, gasFee);
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_NotEnoughGasFee() external {
        uint256 amount = 1 ether;
        uint256 gasFee = 0.01 ether;

        mWethExtension.setGasFee(gasFee);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        vm.expectRevert(ImTokenGateway.mTokenGateway_NotEnoughGasFee.selector);
        mWethExtension.liquidate{value: gasFee - 0.001 ether}(borrower, amount, address(mWethHost), address(this));
    }

    ////////////////////////////////////////////////////////////
    //                       RevertGiven                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertGiven_revertsWith_IsPaused(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountOutHere, true);

        vm.expectRevert();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        mWethExtension.outHere("", "0x123", amounts, address(this));
    }

    modifier givenMarketIsNotPaused() {
        _;
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_AmountIs(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);

        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    ////////////////////////////////////////////////////////////
    //      WhenAccumulatedAmountReceivedOrLessThanNeeded       //
    ////////////////////////////////////////////////////////////

    function test_unitWhenAccumulatedAmountReceivedOrLessThanNeeded_success(uint256 amount)
        external
        givenMarketIsNotPaused
    {
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mTokenGateway_AmountTooBig
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount - 1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountTooBig.selector);
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    ////////////////////////////////////////////////////////////
    //              WhenMarketDoesNotHaveLiquidity              //
    ////////////////////////////////////////////////////////////

    function test_unitWhenMarketDoesNotHaveLiquidity_success(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mTokenGateway_ReleaseCashNotAvailable
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectRevert(ImTokenGateway.mTokenGateway_ReleaseCashNotAvailable.selector);
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_CallerNotAllowedXQ(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);
        _resetContext(users.alice);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectRevert(ImTokenGateway.mTokenGateway_CallerNotAllowed.selector);
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
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

    function test_unitRevertWhen_revertsWith_JournalIsEmpty() external givenMarketIsNotPaused {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_JournalNotValid.selector);
        mWethExtension.outHere("", "0x123", amounts, address(this));
    }

    function test_unitRevertWhen_revertsWith_JournalLengthMismatch() external givenMarketIsNotPaused {
        bytes memory journal =
            _encodeJournal(address(this), address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), true);
        bytes[] memory journals = new bytes[](2);
        journals[0] = journal;
        journals[1] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_LengthNotValid.selector);
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unitRevertWhen_revertsWith_CallerBlacklisted() external givenMarketIsNotPaused {
        blacklister.blacklist(address(this));

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.outHere("", "0x123", new uint256[](0), address(this));
    }

    function test_unitRevertWhen_revertsWith_ReceiverBlacklisted() external givenMarketIsNotPaused {
        blacklister.blacklist(users.alice);

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.outHere("", "0x123", new uint256[](0), users.alice);
    }

    function test_unitRevertWhen_revertsWith_JournalSenderBlacklisted() external givenMarketIsNotPaused {
        blacklister.blacklist(users.alice);

        bytes memory journal =
            _encodeJournal(users.alice, address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), true);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unitRevertWhen_revertsWith_JournalSourceChainInvalid() external givenMarketIsNotPaused {
        bytes memory journal = _encodeJournal(
            address(this), address(mWethExtension), 1, 1, uint32(LINEA_CHAIN_ID + 1), uint32(block.chainid), true
        );
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_ChainNotValid.selector);
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unitRevertWhen_revertsWith_JournalDstChainInvalid() external givenMarketIsNotPaused {
        bytes memory journal = _encodeJournal(
            address(this), address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid + 1), true
        );
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_ChainNotValid.selector);
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_unitRevertWhen_revertsWith_L1InclusionMissing() external givenMarketIsNotPaused {
        bytes memory journal =
            _encodeJournal(address(this), address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), false);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_L1InclusionRequired.selector);
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    ////////////////////////////////////////////////////////////
    //                  WhenParametersAreRight                  //
    ////////////////////////////////////////////////////////////

    function test_unitWhenParametersAreRight_success(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);

        _getTokens(weth, address(mWethExtension), amount);

        uint256 balanceUserBefore = weth.balanceOf(address(this));
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
        uint256 balanceUserAfter = weth.balanceOf(address(this));

        // it should increase accAmountOut
        assertEq(mWethExtension.accAmountOut(address(this)), amount);

        // it should transfer underlying to user
        assertEq(balanceUserBefore + amount, balanceUserAfter);
    }

    ////////////////////////////////////////////////////////////
    //          WhenParametersAreRightDifferentUsersQE          //
    ////////////////////////////////////////////////////////////

    function test_unitWhenParametersAreRightDifferentUsersQE_success(uint256 amount) external givenMarketIsNotPaused {
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
        uint256 balanceUserAfter = weth.balanceOf(address(this));

        // it should increase accAmountOut
        assertEq(mWethExtension.accAmountOut(address(this)), amount);

        // it should transfer underlying to user
        assertEq(balanceUserBefore + amount, balanceUserAfter);
    }

    ////////////////////////////////////////////////////////////
    //                      MTokenGateway                       //
    ////////////////////////////////////////////////////////////

    function test_unitMTokenGateway_revertsWith_supplyOnHost_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.supplyOnHost(0, address(this), LINEA_MINT_SELECTOR);
    }

    function test_unitMTokenGateway_revertsWith_supplyOnHost_RevertWhen_MarketPaused(uint256 amount) external {
        amount = bound(amount, SMALL, LARGE);

        ImTokenGateway(address(mWethExtension)).setPaused(ImTokenOperationTypes.OperationType.AmountIn, true);

        // it should revert
        vm.expectRevert();
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);
    }

    modifier mTokenGateway_supplyOnHost_whenAmountGreaterThan0() {
        // @dev does nothing; for readability only
        _;
    }

    function test_unitMTokenGateway_revertsWith_supplyOnHost_RevertGiven_UserHasNotEnoughBalance(uint256 amount)
        external
        mTokenGateway_supplyOnHost_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        weth.approve(address(mWethExtension), amount);
        vm.expectRevert();
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);
    }

    function test_unitMTokenGateway_success_supplyOnHost_GivenUserHasEnoughBalance(uint256 amount)
        external
        mTokenGateway_supplyOnHost_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }

    function test_unitMTokenGateway_success_supplyOnHost_GivenUserHasEnoughBalance_ButBlacklisted(uint256 amount)
        external
        mTokenGateway_supplyOnHost_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(address(this));
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);
    }

    ////////////////////////////////////////////////////////////
    //                GivenUserHasEnoughBalance                 //
    ////////////////////////////////////////////////////////////

    function test_unitGivenUserHasEnoughBalance_success_ReceiverBlacklisted(uint256 amount)
        external
        mTokenGateway_supplyOnHost_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);
        weth.approve(address(mWethExtension), amount);

        blacklister.blacklist(users.alice);
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.supplyOnHost(amount, users.alice, LINEA_MINT_SELECTOR);
    }

    ////////////////////////////////////////////////////////////
    //                      MTokenGateway                       //
    ////////////////////////////////////////////////////////////

    function test_unitMTokenGateway_success_supplyOnHost_GivenUserHasEnoughBalance_ButWhitelistEnabled(uint256 amount)
        external
        mTokenGateway_supplyOnHost_whenAmountGreaterThan0
    {
        amount = bound(amount, SMALL, LARGE);

        _getTokens(weth, address(this), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));

        weth.approve(address(mWethExtension), amount);

        mWethExtension.enableWhitelist();

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        mWethExtension.setWhitelistedUser(address(this), false);
        vm.expectRevert(ImTokenGateway.mTokenGateway_UserNotWhitelisted.selector);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        mWethExtension.setWhitelistedUser(address(this), true);
        mWethExtension.supplyOnHost(amount, address(this), LINEA_MINT_SELECTOR);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }

    ////////////////////////////////////////////////////////////
    //                      WrapAndSupply                       //
    ////////////////////////////////////////////////////////////

    function test_unitWrapAndSupply_success() external {
        WrapAndSupply wrapAndSupply = new WrapAndSupply(address(weth));
        vm.label(address(wrapAndSupply), "WrapAndSupply Helper");

        uint256 accAmountInBefore = mWethExtension.accAmountIn(address(this));
        wrapAndSupply.wrapAndSupplyOnExtensionMarket{value: SMALL}(
            address(mWethExtension), address(this), LINEA_MINT_SELECTOR
        );
        uint256 accAmountInAfter = mWethExtension.accAmountIn(address(this));

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }
}
