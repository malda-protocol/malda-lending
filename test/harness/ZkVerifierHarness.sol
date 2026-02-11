// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

contract ZkVerifierHarness is ZkVerifier {
    constructor(address owner_, bytes32 imageId_, address verifier_) ZkVerifier(owner_, imageId_, verifier_) {}

    function setVerifierUnsafe(address verifier_) external {
        verifier = IRiscZeroVerifier(verifier_);
    }
}
