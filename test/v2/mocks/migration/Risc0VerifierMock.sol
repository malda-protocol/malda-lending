// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

contract Risc0VerifierMock {
    struct Receipt {
        bytes seal;
        bytes32 claimDigest;
    }

    bool public shouldRevert;

    function setStatus(bool failure) external {
        shouldRevert = failure;
    }

    function verify(bytes calldata, bytes32, bytes32) external view {
        if (shouldRevert) revert("Failure");
    }

    function verifyIntegrity(Receipt calldata) external view {
        if (shouldRevert) revert("Failure");
    }
}
