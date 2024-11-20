// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {BytesLib} from "src/libraries/BytesLib.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mTokenGateway_borrow is mToken_Unit_Shared {
    function test_RevertWhen_AmountIs0() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.borrowOnHost(0);
    }

    function test_WhenAmountGreaterThan0XA(uint256 amount) external inRange(amount, SMALL, LARGE) {
        _borrowGatewayPrerequisites(address(mWethExtension), amount);

        mWethExtension.borrowOnHost(amount);

        // it should increase nonce for this operation type
        assertEq(
            mWethExtension.getNonce(
                address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.BorrowOnOtherChain
            ),
            1
        );

        // it should not increase nonce for any other operation type
        assertEq(
            mWethExtension.getNonce(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Mint), 0
        );
        assertEq(
            mWethExtension.getNonce(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Repay), 0
        );

        // check logs
        _checkLog(
            ImTokenOperationTypes.OperationType.BorrowOnOtherChain, amount, 0, uint32(block.chainid), LINEA_CHAIN_ID
        );
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
        mWethExtension.borrowExternal("", "0x123");
    }

    function test_GivenDecodedAmountIs0XXXX() external whenBorrowExternalIsCalled whenImageIdExists {
        uint256 amount = 0;
        bytes memory journalData = _createJournal(
            amount,
            address(this),
            mWethExtension.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Borrow)
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
        bytes memory journalData = _createJournal(
            amount,
            address(this),
            mWethExtension.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Borrow)
        );

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethExtension.borrowExternal(journalData, "0x123");
    }

    function test_WhenSealVerificationWasOkXQ(uint256 amount)
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

        uint32 nonce =
            mWethExtension.nonces(address(this), uint32(block.chainid), ImTokenOperationTypes.OperationType.Borrow);
        bytes memory journalData = _createCommitmentWithDstChain(amount, address(this), nonce, 100);
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

        // verify logs
        _checkLog(ImTokenOperationTypes.OperationType.Borrow, amount, nonce, 100, uint32(block.chainid));
    }

    function _checkLog(
        ImTokenOperationTypes.OperationType opType,
        uint256 amount,
        uint32 nonce,
        uint32 srcChainId,
        uint32 dstChainId
    ) private view {
        (uint256 journalDstChainId, bytes memory encodedData) =
            operationsLog.getLogForChain(address(this), opType, nonce, srcChainId);
        assertGt(encodedData.length, 0);
        assertEq(journalDstChainId, dstChainId);

        // decode action data
        // | Offset | Length | Data Type       |
        // |--------|--------|-----------------|
        // | 0     | 32     | uint256 decodedAmount  |
        // | 32    | 20     | address decodedSender    |
        // | 52    | 4      | uint32 decodedNonce    |
        // | 56    | 4      | uint32 decodedSrcChainId  |
        uint256 decodedAmount = BytesLib.toUint256(BytesLib.slice(encodedData, 0, 32), 0);
        address decodedSender = BytesLib.toAddress(BytesLib.slice(encodedData, 32, 20), 0);
        uint32 decodedNonce = BytesLib.toUint32(BytesLib.slice(encodedData, 52, 4), 0);
        uint32 decodedSrcChainId = BytesLib.toUint32(BytesLib.slice(encodedData, 56, 4), 0);

        assertEq(decodedAmount, amount);
        assertEq(decodedSender, address(this));
        assertEq(decodedNonce, nonce);
        assertEq(decodedSrcChainId, srcChainId);
    }
}
