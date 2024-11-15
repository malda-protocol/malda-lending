// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

// contracts
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";

// tests
import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20Host_redeem is mToken_Unit_Shared {
    function test_RevertGiven_MarketIsPausedForRdeem(uint256 amount)
        external
        whenPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWethHost.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        mWethHost.redeemUnderlying(amount);
    }

    function test_GivenMarketIsNotListed(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        inRange(amount, SMALL, LARGE)
    {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWethHost.redeem(amount);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        mWethHost.redeemUnderlying(amount);
    }

    function test_GivenRedeemerIsNotPartOfTheMarket(uint256 amount)
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        _getTokens(weth, address(mWethHost), amount);
        vm.expectRevert();
        mWethHost.redeem(amount);

        vm.expectRevert();
        mWethHost.redeemUnderlying(amount);
    }

    function test_GivenRedeemAmountsAre0()
        external
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        whenMarketIsListed(address(mWethHost))
    {
        vm.expectRevert(mTokenStorage.mToken_RedeemEmpty.selector);
        mWethHost.redeem(0);
        vm.expectRevert(mTokenStorage.mToken_RedeemEmpty.selector);
        mWethHost.redeemUnderlying(0);
    }

    modifier givenAmountIsGreaterThan0() {
        // does nothing; only for readability purposes
        _;
    }

    function test_WhenTheMarketDoesNotHaveEnoughAssetsForTheRedeemOperation(uint256 amount)
        external
        givenAmountIsGreaterThan0
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        // it should revert with mToken_RedeemCashNotAvailable
        vm.expectRevert(mTokenStorage.mToken_RedeemCashNotAvailable.selector);
        mWethHost.redeem(amount);

        vm.expectRevert(mTokenStorage.mToken_RedeemCashNotAvailable.selector);
        mWethHost.redeemUnderlying(amount);
    }

    function test_WhenStateIsValidForRedeem(uint256 amount)
        external
        givenAmountIsGreaterThan0
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        _redeem(amount, false);
    }

    function test_WhenStateIsValidForRedeemUnderlying(uint256 amount)
        external
        givenAmountIsGreaterThan0
        whenNotPaused(address(mWethHost), ImTokenOperationTypes.OperationType.Redeem)
        inRange(amount, SMALL, LARGE)
        whenMarketIsListed(address(mWethHost))
    {
        _redeem(amount, true);
    }

    function _redeem(uint256 amount, bool underlying) private {
        _borrowPrerequisites(address(mWethHost), amount);

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 supplyMTokenBefore = mWethHost.totalSupply();
        uint256 balanceMTokenBefore = mWethHost.balanceOf(address(this));

        amount = amount - DEFAULT_INFLATION_INCREASE;
        if (underlying) mWethHost.redeemUnderlying(amount);
        else mWethHost.redeem(amount);

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 supplyMTokenAfter = mWethHost.totalSupply();
        uint256 balanceMTokenAfter = mWethHost.balanceOf(address(this));

        // it should transfer underlying to redeemer
        assertEq(balanceWethBefore + amount, balanceWethAfter);

        // it should decrease totalSupply of mToken
        assertGt(supplyMTokenBefore, supplyMTokenAfter);
        assertEq(supplyMTokenBefore - amount, supplyMTokenAfter);

        // it should decrease redeemer balance of mToken
        assertGt(balanceMTokenBefore, balanceMTokenAfter);
        assertEq(balanceMTokenBefore - amount, balanceMTokenAfter);
    }

    modifier whenRedeemExternalIsCalled() {
        // @dev does nothing; just for readability
        _;
    }

    modifier givenDecodedAmountIsValid() {
        // @dev does nothing; just for readability
        _;
    }

    function test_RevertGiven_JournalIsEmpty(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenRedeemExternalIsCalled
    {
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.withdrawExternal("", "0x123");
    }

    function test_RevertGiven_JournalIsNonEmptyButLengthIsNotValid(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenRedeemExternalIsCalled
    {
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.withdrawExternal("0x123", "0x123");
    }

    function test_GivenDecodedAmountIs0() external whenRedeemExternalIsCalled whenImageIdExists {
        uint256 amount = 0;
        bytes memory journalData = _createCommitment(
            amount,
            address(this),
            mWethHost.nonces(address(this), block.chainid, ImTokenOperationTypes.OperationType.Redeem)
        );

        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);
        mWethHost.withdrawExternal(journalData, "0x123");
    }

    function test_RevertWhen_SealVerificationFails(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenRedeemExternalIsCalled
        whenImageIdExists
        givenDecodedAmountIsValid
    {
        bytes memory journalData = _createCommitment(
            amount,
            address(this),
            mWethHost.nonces(address(this), block.chainid, ImTokenOperationTypes.OperationType.Redeem)
        );

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethHost.withdrawExternal(journalData, "0x123");
    }

    function test_WhenSealVerificationWasOk(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenRedeemExternalIsCalled
        whenImageIdExists
        givenDecodedAmountIsValid
        whenMarketIsListed(address(mWethHost))
    {
        _borrowPrerequisites(address(mWethHost), amount);

        amount = amount - DEFAULT_INFLATION_INCREASE;

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        bytes memory journalData = _createCommitment(
            amount,
            address(this),
            mWethHost.nonces(address(this), block.chainid, ImTokenOperationTypes.OperationType.Redeem)
        );
        mWethHost.withdrawExternal(journalData, "0x123");

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertGt(balanceOfBefore, balanceOfAfter, "A");
        assertEq(balanceOfAfter + amount, balanceOfBefore, "B");

        // it should decrease total supply by amount
        assertGt(totalSupplyBefore, totalSupplyAfter, "C");
        assertEq(totalSupplyBefore - amount, totalSupplyAfter, "D");

        // it should transfer
        assertEq(balanceWethBefore + amount, balanceWethAfter, "F");
    }

    function test_RevertGiven_TheSameCommitmentIdIsUsed(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenRedeemExternalIsCalled
        whenImageIdExists
        givenDecodedAmountIsValid
        whenMarketIsListed(address(mWethHost))
    {
        _borrowPrerequisites(address(mWethHost), amount);

        amount = amount - DEFAULT_INFLATION_INCREASE;

        bytes memory journalData = _createCommitment(
            amount,
            address(this),
            mWethHost.nonces(address(this), block.chainid, ImTokenOperationTypes.OperationType.Redeem)
        );
        mWethHost.withdrawExternal(journalData, "0x123");

        vm.expectRevert();
        mWethHost.withdrawExternal(journalData, "0x123");
    }

    modifier whenWithdrawOnExtensionIsCalled() {
        // @dev does nothing; just for readability
        _;
    }

    modifier givenDecodedLiquidityIsValid() {
        // @dev does nothing; just for readability
        _;
    }

    function test_RevertGiven_LiquidityJournalIsEmpty(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenWithdrawOnExtensionIsCalled
    {
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.withdrawOnExtension(amount, "", "0x123");
    }

    function test_RevertGiven_LiquidityJournalIsNonEmptyButLengthIsNotValid(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenWithdrawOnExtensionIsCalled
    {
        vm.expectRevert(ImErc20Host.mErc20Host_JournalNotValid.selector);
        mWethHost.withdrawOnExtension(amount, "0x123", "0x123");
    }

    function test_GivenDecodedLiquidityIs0XXX() external whenWithdrawOnExtensionIsCalled whenImageIdExists {
        uint256 amount = 0;
        bytes memory journalData = _createCommitmentWithDstChain(amount, address(this), 1);

        vm.expectRevert(ImErc20Host.mErc20Host_AmountNotValid.selector);
        mWethHost.withdrawOnExtension(amount, journalData, "0x123");
    }

    function test_RevertWhen_LiquiditySealVerificationFails(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenWithdrawOnExtensionIsCalled
        whenImageIdExists
        givenDecodedLiquidityIsValid
    {
        bytes memory journalData = _createCommitment(amount, address(this));

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethHost.withdrawOnExtension(amount, journalData, "0x123");
    }

    function test_WhenLiquiditySealVerificationWasOk(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenWithdrawOnExtensionIsCalled
        whenImageIdExists
        givenDecodedLiquidityIsValid
        whenMarketIsListed(address(mWethHost))
    {
        _borrowPrerequisites(address(mWethHost), amount);

        amount = amount - DEFAULT_INFLATION_INCREASE;

        uint256 balanceWethBefore = weth.balanceOf(address(this));
        uint256 totalSupplyBefore = mWethHost.totalSupply();
        uint256 balanceOfBefore = mWethHost.balanceOf(address(this));

        bytes memory journalData = _createCommitmentWithDstChain(amount, address(this), 1);
        mWethHost.withdrawOnExtension(amount, journalData, "0x123");

        uint256 balanceWethAfter = weth.balanceOf(address(this));
        uint256 totalSupplyAfter = mWethHost.totalSupply();
        uint256 balanceOfAfter = mWethHost.balanceOf(address(this));

        // it should increse balanceOf account
        assertEq(balanceOfAfter + amount, balanceOfBefore, "B");

        // it should decrease total supply by amount
        assertGt(totalSupplyBefore, totalSupplyAfter, "C");
        assertEq(totalSupplyBefore - amount, totalSupplyAfter, "D");

        // it should transfer
        assertEq(balanceWethBefore, balanceWethAfter, "F");
    }

    function test_RevertGiven_TheSameLiquidityCommitmentIdIsUsed(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenWithdrawOnExtensionIsCalled
        whenImageIdExists
        givenDecodedLiquidityIsValid
        whenMarketIsListed(address(mWethHost))
    {
        _borrowPrerequisites(address(mWethHost), amount);

        amount = amount - DEFAULT_INFLATION_INCREASE;

        bytes memory journalData = _createCommitmentWithDstChain(amount, address(this), 1);
        mWethHost.withdrawOnExtension(amount, journalData, "0x123");

        vm.expectRevert(abi.encodePacked(ZkVerifier.ZkVerifier_AlreadyVerified.selector, uint256(1)));
        mWethHost.withdrawOnExtension(amount, journalData, "0x123");
    }
}
