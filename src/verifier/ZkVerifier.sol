// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This file contains code derived from or inspired by Risc0,
// originally licensed under the Apache License 2.0. See LICENSE-RISC0
// and the NOTICE file for original license terms and attributions.

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

// interfaces
import {IRiscZeroVerifier} from "risc0/IRiscZeroVerifier.sol";

// contracts
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Zero-knowledge verifier interface
/// @author Malda Protocol
/// @notice Minimal interface to verify a Risc0 proof
interface IZkVerifier {
    /// @notice Verify the provided Risc0 journal/seal pair
    /// @param journalEntry The Risc0 journal entry
    /// @param seal The proof seal
    function verifyInput(bytes calldata journalEntry, bytes calldata seal) external view;
}

/// @title Zero-knowledge verifier wrapper
/// @author Malda Protocol
/// @notice Ownable wrapper around the Risc0 verifier with configurable imageId
contract ZkVerifier is Ownable, IZkVerifier {
    // ----------- STORAGE ------------
    /// @notice Current Risc0 verifier contract
    IRiscZeroVerifier public verifier;

    /// @notice Current Risc0 image identifier
    bytes32 public imageId;

    // ----------- EVENTS ------------
    /// @notice Emitted when the imageId is updated
    /// @param _imageId New image identifier
    event ImageSet(bytes32 _imageId);

    /// @notice Emitted when the verifier contract address is updated
    /// @param oldVerifier Previous verifier address
    /// @param newVerifier New verifier address
    event VerifierSet(address indexed oldVerifier, address indexed newVerifier);

    // ----------- ERRORS ------------
    error ZkVerifier_ImageNotValid();
    error ZkVerifier_InputNotValid();
    error ZkVerifier_VerifierNotSet();

    /// @notice Initializes the verifier wrapper
    /// @param owner_ Contract owner
    /// @param _imageId Risc0 image identifier
    /// @param _verifier Risc0 verifier contract address
    constructor(address owner_, bytes32 _imageId, address _verifier) Ownable(owner_) {
        require(_verifier != address(0), ZkVerifier_InputNotValid());
        require(_imageId != bytes32(0), ZkVerifier_InputNotValid());
        verifier = IRiscZeroVerifier(_verifier);
        imageId = _imageId;
    }

    // ----------- OWNER ------------
    /// @notice Sets the _risc0Verifier address
    /// @dev Admin check is needed on the external method
    /// @param _risc0Verifier the new IRiscZeroVerifier address
    function setVerifier(address _risc0Verifier) external onlyOwner {
        require(_risc0Verifier != address(0), ZkVerifier_InputNotValid());
        emit VerifierSet(address(verifier), _risc0Verifier);
        verifier = IRiscZeroVerifier(_risc0Verifier);
    }

    /// @notice Sets the image id
    /// @dev Admin check is needed on the external method
    /// @param _imageId the new image id
    function setImageId(bytes32 _imageId) external onlyOwner {
        require(_imageId != bytes32(0), ZkVerifier_ImageNotValid());
        emit ImageSet(_imageId);
        imageId = _imageId;
    }

    // ----------- VIEW ------------
    /// @notice Verifies an input
    /// @param journalEntry the risc0 journal entry
    /// @param seal the risc0 seal
    function verifyInput(bytes calldata journalEntry, bytes calldata seal) external view {
        // generic checks
        _checkAddresses();

        // verify input
        __verify(journalEntry, seal);
    }

    // ----------- PRIVATE ------------
    /// @notice Ensures verifier is configured
    function _checkAddresses() private view {
        require(address(verifier) != address(0), ZkVerifier_VerifierNotSet());
    }

    /// @notice Internal verification against the configured image
    /// @param journalEntry the Risc0 journal entry
    /// @param seal the Risc0 seal
    function __verify(bytes calldata journalEntry, bytes calldata seal) private view {
        verifier.verify(seal, imageId, sha256(journalEntry));
    }
}
