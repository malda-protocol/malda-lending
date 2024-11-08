// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

contract mTokenGateway_release is mToken_Unit_Shared {
    modifier existingImageId() {
        verifierImageRegistry.addImageId(bytes32("0x1233"));
        verifierImageRegistry.addImageId(bytes32("0x1234"));
        verifierImageRegistry.addImageId(bytes32("0x1235"));
        verifierImageRegistry.addImageId(bytes32("0x1236"));
        verifierImageRegistry.addImageId(bytes32("0x1237"));
        verifierImageRegistry.addImageId(bytes32("0x1238"));
        verifierImageRegistry.addImageId(bytes32("0x1239"));
        verifierImageRegistry.addImageId(bytes32("0x1240"));
        verifierImageRegistry.addImageId(bytes32("0x1241"));
        _;
    }

    function test_RevertGiven_JournalIsEmpty() external {
        vm.expectRevert(ImTokenGateway.mTokenGateway_JournalNotValid.selector);
        mWethExtension.withdrawExternal("", "0x123");
    }

    function test_RevertGiven_JournalIsNonEmptyButLengthIsNotValid() external {
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_JournalNotValid.selector);
        mWethExtension.withdrawExternal("0x123", "0x123");
    }

    function test_GivenDecodedAmountIs0X() external existingImageId {
        uint256 amount = 0;
        bytes memory journalData = _createCommitment(
            amount,
            address(this),
            mWethExtension.nonces(address(this), block.chainid, ImTokenGateway.OperationType.WithdrawExternal)
        );

        // it should revert with mErc20Host_AmountNotValid
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);
        mWethExtension.withdrawExternal(journalData, "0x123");
    }

    modifier givenDecodedAmountIsValid() {
        // @dev does nothing; for readability only
        _;
    }

    function test_RevertWhen_SealVerificationFails(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenDecodedAmountIsValid
        existingImageId
    {
        bytes memory journalData = _createCommitment(
            amount,
            address(this),
            mWethExtension.nonces(address(this), block.chainid, ImTokenGateway.OperationType.WithdrawExternal)
        );

        verifierMock.setStatus(true); // set for failure

        vm.expectRevert();
        mWethExtension.withdrawExternal(journalData, "0x123");
    }

    modifier whenSealVerificationWasOk() {
        // @dev does nothing; for readability only
        _;
    }

    function test_RevertGiven_TheresNotEnoughUnderlyingBalance(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenDecodedAmountIsValid
        whenSealVerificationWasOk
        existingImageId
    {
        bytes memory journalData = _createCommitment(
            amount,
            address(this),
            mWethExtension.nonces(address(this), block.chainid, ImTokenGateway.OperationType.WithdrawExternal)
        );

        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountTooBig.selector);
        mWethExtension.withdrawExternal(journalData, "0x123");
    }

    modifier givenTheContractHasUnderlying() {
        // @dev does nothing; for readability only
        _;
    }

    function test_RevertWhen_NonceIsNotValidX(uint256 amount)
        external
        inRange(amount, SMALL, LARGE)
        givenDecodedAmountIsValid
        whenSealVerificationWasOk
        givenTheContractHasUnderlying
        existingImageId
    {
        bytes memory journalData = _createCommitment(amount, address(this), 100);
        // it should revert
        vm.expectRevert(ImTokenGateway.mTokenGateway_NonceNotValid.selector);
        mWethExtension.withdrawExternal(journalData, "0x123");
    }

    function test_WhenNonceIsValid()
        external
        givenDecodedAmountIsValid
        whenSealVerificationWasOk
        givenTheContractHasUnderlying
    {
        // it should decrease pending amounts
        // it should update the logs for the caller
        // it should transfer underlying to caller
        // it should increase nonce
        // it should not increase nonce for any other operation type
    }
}
