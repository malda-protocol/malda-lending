// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mToken_Unit_Shared} from "test/unit/shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_outHere is mToken_Unit_Shared {
    function setUp() public virtual override {
        super.setUp();

        vm.chainId(LINEA_CHAIN_ID);
    }

    function test_RevertGiven_IsPaused(uint256 amount) external {
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

    function test_RevertWhen_AmountIs(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);

        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    function test_WhenAccumulatedAmountReceivedOrLessThanNeeded(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mTokenGateway_AmountTooBig
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount - 1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountTooBig.selector);
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    function test_WhenMarketDoesNotHaveLiquidity(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        // it should revert with mTokenGateway_ReleaseCashNotAvailable
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.expectRevert(ImTokenGateway.mTokenGateway_ReleaseCashNotAvailable.selector);
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
    }

    function test_RevertWhen_CallerNotAllowedXQ(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        // it should revert
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);
        _resetContext(alice);
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

    function test_RevertWhen_JournalIsEmpty() external givenMarketIsNotPaused {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_JournalNotValid.selector);
        mWethExtension.outHere("", "0x123", amounts, address(this));
    }

    function test_RevertWhen_JournalLengthMismatch() external givenMarketIsNotPaused {
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

    function test_RevertWhen_CallerBlacklisted() external givenMarketIsNotPaused {
        blacklister.blacklist(address(this));

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.outHere("", "0x123", new uint256[](0), address(this));
    }

    function test_RevertWhen_ReceiverBlacklisted() external givenMarketIsNotPaused {
        blacklister.blacklist(alice);

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.outHere("", "0x123", new uint256[](0), alice);
    }

    function test_RevertWhen_JournalSenderBlacklisted() external givenMarketIsNotPaused {
        blacklister.blacklist(alice);

        bytes memory journal =
            _encodeJournal(alice, address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), true);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_UserBlacklisted.selector);
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_RevertWhen_JournalSourceChainInvalid() external givenMarketIsNotPaused {
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

    function test_RevertWhen_JournalDstChainInvalid() external givenMarketIsNotPaused {
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

    function test_RevertWhen_L1InclusionMissing() external givenMarketIsNotPaused {
        bytes memory journal =
            _encodeJournal(address(this), address(mWethExtension), 1, 1, LINEA_CHAIN_ID, uint32(block.chainid), false);
        bytes[] memory journals = new bytes[](1);
        journals[0] = journal;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.expectRevert(ImTokenGateway.mTokenGateway_L1InclusionRequired.selector);
        mWethExtension.outHere(_wrapJournals(journals), "0x123", amounts, address(this));
    }

    function test_WhenParametersAreRight(uint256 amount) external givenMarketIsNotPaused {
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

    function test_WhenParametersAreRightDifferentUsersQE(uint256 amount) external givenMarketIsNotPaused {
        amount = bound(amount, SMALL, LARGE);

        vm.chainId(LINEA_CHAIN_ID);
        address[] memory allowerdCallers = new address[](1);
        allowerdCallers[0] = alice;
        bytes memory journalData = _createAccumulatedAmountJournal(address(this), address(mWethExtension), amount);

        _getTokens(weth, address(mWethExtension), amount);

        uint256 balanceUserBefore = weth.balanceOf(address(this));
        mWethExtension.updateAllowedCallerStatus(alice, true);
        _resetContext(alice);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        mWethExtension.outHere(journalData, "0x123", amounts, address(this));
        uint256 balanceUserAfter = weth.balanceOf(address(this));

        // it should increase accAmountOut
        assertEq(mWethExtension.accAmountOut(address(this)), amount);

        // it should transfer underlying to user
        assertEq(balanceUserBefore + amount, balanceUserAfter);
    }
}
