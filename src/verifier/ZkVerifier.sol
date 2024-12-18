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
import {Steel} from "risc0/steel/Steel.sol";

abstract contract ZkVerifier {
    // ----------- STORAGE ------------
    IRiscZeroVerifier public verifier;

    bytes32 public imageId;

    error ZkVerifier_ImageNotValid();
    error ZkVerifier_InputNotValid();
    error ZkVerifier_VerifierNotSet();
    error ZkVerifier_AlreadyInitialized();

    event ImageSet(bytes32 _imageId);
    event VerifierSet(address indexed oldVerifier, address indexed newVerifier);

    bool private _verifierInitialized;

    modifier initializer() {
        if (_verifierInitialized) revert ZkVerifier_AlreadyInitialized();
        _;
        _verifierInitialized = true;
    }

    // ----------- PUBLIC ------------
    /**
     * @notice Initializes a new ZkVerifier contract
     * @param _verifier IRiscZeroVerifier contract implementation
     */
    function initialize(address _verifier) public initializer {
        verifier = IRiscZeroVerifier(_verifier);
    }

    // ----------- INTERNAL ------------
    /**
     * @notice Sets the _risc0Verifier address
     * @dev Admin check is needed on the external method
     * @param _risc0Verifier the new IRiscZeroVerifier address
     */
    function _setVerifier(address _risc0Verifier) internal {
        emit VerifierSet(address(verifier), _risc0Verifier);
        verifier = IRiscZeroVerifier(_risc0Verifier);
    }

    /**
     * @notice Sets the image id
     * @dev Admin check is needed on the external method
     * @param _imageId the new image id
     */
    function _setImageId(bytes32 _imageId) internal {
        require(_imageId != bytes32(0), ZkVerifier_ImageNotValid());
        emit ImageSet(_imageId);
        imageId = _imageId;
    }

    /**
     * @notice Verifies an input
     * @param journalEntry the risc0 journal entry
     * @param seal the risc0 seal
     */
    function _verifyInput(bytes calldata journalEntry, bytes calldata seal) internal virtual {
        // generic checks
        _checkAddresses();

        // verify input
        __verify(journalEntry, seal);
    }

    // ----------- PRIVATE ------------
    function _checkAddresses() private view {
        require(address(verifier) != address(0), ZkVerifier_VerifierNotSet());
    }

    function __verify(bytes calldata journalEntry, bytes calldata seal) private view {
        verifier.verify(seal, imageId, sha256(journalEntry));
    }
}
