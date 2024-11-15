// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

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
                address(this), block.chainid, ImTokenOperationTypes.OperationType.BorrowOnOtherChain
            ),
            1
        );

        // it should not increase nonce for any other operation type
        assertEq(mWethExtension.getNonce(address(this), block.chainid, ImTokenOperationTypes.OperationType.Mint), 0);
        assertEq(mWethExtension.getNonce(address(this), block.chainid, ImTokenOperationTypes.OperationType.Repay), 0);

        // check logs
        _checkLog(ImTokenOperationTypes.OperationType.BorrowOnOtherChain, amount, 0, block.chainid, LINEA_CHAIN_ID);
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
            amount,
            address(this),
            mWethExtension.nonces(address(this), block.chainid, ImTokenOperationTypes.OperationType.Borrow)
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
            amount,
            address(this),
            mWethExtension.nonces(address(this), block.chainid, ImTokenOperationTypes.OperationType.Borrow)
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

        uint256 nonce = mWethExtension.nonces(address(this), block.chainid, ImTokenOperationTypes.OperationType.Borrow);
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
        _checkLog(ImTokenOperationTypes.OperationType.Borrow, amount, nonce, 100, block.chainid);
    }

    function _checkLog(
        ImTokenOperationTypes.OperationType opType,
        uint256 amount,
        uint256 nonce,
        uint256 srcChainId,
        uint256 dstChainId
    ) private view {
        (uint256 journalDstChainId, bytes memory encodedData) =
            operationsLog.getLogForChain(address(this), opType, nonce, srcChainId);
        assertGt(encodedData.length, 0);
        assertEq(journalDstChainId, dstChainId);

        (uint256 decodedAmount, address decodedSender, uint256 decodedNonce, uint256 decodedSrcChainId) =
            abi.decode(encodedData, (uint256, address, uint256, uint256));
        assertEq(decodedAmount, amount, "A");
        assertEq(decodedSender, address(this), "B");
        assertEq(decodedNonce, nonce, "C");
        assertEq(decodedSrcChainId, srcChainId, "D");
    }
}
