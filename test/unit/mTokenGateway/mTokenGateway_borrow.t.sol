// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

contract mTokenGateway_borrow is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.borrowOnHost(0);
    }

    function test_WhenAmountGreaterThan0(uint256 amount) external inRange(amount, SMALL, LARGE) {
        _borrowGatewayPrerequisites(address(mWethExtension), amount);

        mWethExtension.borrowOnHost(amount);

        // it should update the logs for the caller
        assertEq(mWethExtension.getLogsLength(address(this), block.chainid, ImTokenGateway.OperationType.Borrow), 1);
        assertEq(mWethExtension.getLogsLength(address(this), block.chainid, ImTokenGateway.OperationType.Mint), 1);
        assertEq(mWethExtension.getLogsLength(address(this), block.chainid, ImTokenGateway.OperationType.Repay), 0);

        // it should increase nonce for this operation type
        assertEq(mWethExtension.getNonce(address(this), block.chainid, ImTokenGateway.OperationType.Borrow), 1);

        // it should not increase nonce for any other operation type
        assertEq(mWethExtension.getNonce(address(this), block.chainid, ImTokenGateway.OperationType.Mint), 1);
        assertEq(mWethExtension.getNonce(address(this), block.chainid, ImTokenGateway.OperationType.Repay), 0);
    }

    modifier whenBorrowExternalIsCalled() {
        // @dev does nothing; for readability only
        _;
    }

    modifier givenDecodedAmountIsValid() {
        // @dev does nothing; for readability only
        _;
    }

    function test_RevertGiven_JournalIsEmpty(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenBorrowExternalIsCalled
    {
        vm.expectRevert(ImTokenGateway.mTokenGateway_JournalNotValid.selector);
        mWethExtension.borrowExternal("", "0x123");
    }

    function test_RevertGiven_JournalIsNonEmptyButLengthIsNotValid(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenBorrowExternalIsCalled
    {
        vm.expectRevert(ImTokenGateway.mTokenGateway_JournalNotValid.selector);
        mWethExtension.borrowExternal("0x123", "0x123");
    }

    function test_GivenDecodedAmountIs0XXXX() external whenBorrowExternalIsCalled whenImageIdExists {
        uint256 amount = 0;
        bytes memory journalData = _createCommitment(
            amount, address(this), mWethExtension.nonces(address(this), block.chainid, ImTokenGateway.OperationType.BorrowExternal)
        );

        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.borrowExternal(journalData, "0x123");
    }

    function test_RevertWhen_SealVerificationFails(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenBorrowExternalIsCalled
        whenImageIdExists
        givenDecodedAmountIsValid
    {
        bytes memory journalData = _createCommitment(
            amount, address(this), mWethExtension.nonces(address(this), block.chainid, ImTokenGateway.OperationType.BorrowExternal)
        );

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethExtension.borrowExternal(journalData, "0x123");
    }

    function test_WhenSealVerificationWasOk(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        whenUnderlyingPriceIs(DEFAULT_ORACLE_PRICE)
        whenBorrowExternalIsCalled
        whenImageIdExists
        givenDecodedAmountIsValid
    {
        // supply tokens
        _getTokens(weth, address(mWethExtension), amount * 2);

        // before state
        uint256 balanceUnderlyingBefore = weth.balanceOf(address(this));
        uint256 balanceUnderlyingMTokenBefore = weth.balanceOf(address(mWethExtension));
        uint256 supplyUnderlyingBefore = weth.totalSupply();

        bytes memory journalData = _createCommitment(
            amount, address(this), mWethExtension.nonces(address(this), block.chainid, ImTokenGateway.OperationType.BorrowExternal)
        );
        mWethExtension.borrowExternal(journalData, "0x123");

        {
            uint256 balanceUnderlyingAfter = weth.balanceOf(address(this));
            uint256 balanceUnderlyingMTokenAfter = weth.balanceOf(address(mWethExtension));
            uint256 supplyUnderlyingAfter = weth.totalSupply();

             // it should transfer underlying token to sender
            assertGt(balanceUnderlyingAfter, balanceUnderlyingBefore);
            assertEq(balanceUnderlyingAfter - amount, balanceUnderlyingBefore);

            // it should not modify underlying supply
            assertEq(supplyUnderlyingBefore, supplyUnderlyingAfter);

            // it should decrease balance of underlying from mToken
            assertGt(balanceUnderlyingMTokenBefore, balanceUnderlyingMTokenAfter);
        }

    }
}
