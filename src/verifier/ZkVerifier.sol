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
import {IZkVerifierImageRegistry} from "../interfaces/IZkVerifierImageRegistry.sol";

// contracts
import {Steel} from "risc0/steel/Steel.sol";

abstract contract ZkVerifier {
    // ----------- STORAGE ------------
    IRiscZeroVerifier public verifier;
    IZkVerifierImageRegistry public verifierImageRegistry;

    mapping(uint256 => bool) private _validatedCommitments;

    struct VerifierBatchData {
        bytes[] journalEntries;
        Steel.Commitment[] commitments;
        bytes[] seals;
        /**
         * @dev only one of the below is used
         *      Both needs to have the same length
         *      `imageIds` has priority over `imageIdIndexes`
         */
        bytes32[] imageIds;
        uint256[] imageIdIndexes;
    }

    error ZkVerifier_OnlyAdmin();
    error ZkVerifier_ImageNotValid();
    error ZkVerifier_InputNotValid();
    error ZkVerifier_VerifierNotSet();
    error ZkVerifier_VerifierImageRegistryNotSet();
    error ZkVerifier_AlreadyVerified(uint256 commitmentId);
    error ZkVerifier_InvalidCommitment(uint256 commitmentId);

    event VerifierSet(address indexed oldVerifier, address indexed newVerifier);
    event VerifierImageRegistrySet(address indexed oldRegistry, address indexed newRegistry);

    // ----------- PUBLIC ------------
    /**
     * @notice Initializes a new ZkVerifier contract
     * @param _verifier IRiscZeroVerifier contract implementation
     */
    function initialize(address _verifier, address _verifierImageRegistry) public {
        verifier = IRiscZeroVerifier(_verifier);

        verifierImageRegistry = IZkVerifierImageRegistry(_verifierImageRegistry);
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
     * @notice Sets the IZkVerifierImageRegistry
     * @dev Admin check is needed on the external method
     * @param _imageRegistry the new image registry address
     */
    function _setVerifierImageRegistry(address _imageRegistry) internal {
        emit VerifierImageRegistrySet(address(verifierImageRegistry), _imageRegistry);
        verifierImageRegistry = IZkVerifierImageRegistry(_imageRegistry);
    }

    /**
     * @notice Verifies an input on an extension chain
     * @param journalEntry the risc0 journal entry
     * @param seal the risc0 seal
     * @param imageIdIndex the risc0 imageId index available in the registry
     */
    function _verifyInput(bytes calldata journalEntry, bytes calldata seal, uint256 imageIdIndex) internal virtual {
        // generic checks
        _checkAddresses();

        // check image
        bytes32 _imageId;
        _imageId = _checkImage(_imageId, imageIdIndex);

        // verify input
        verifier.verify(seal, _imageId, sha256(journalEntry));
    }

    /**
     * @notice Verifies an input
     * @param journalEntry the risc0 journal entry
     * @param commitment the risc0 journal comittment
     * @param seal the risc0 seal
     * @param imageIdIndex the risc0 imageId index available in the registry
     */
    function _verifyInput(
        bytes calldata journalEntry,
        Steel.Commitment memory commitment,
        bytes calldata seal,
        uint256 imageIdIndex
    ) internal virtual {
        // generic checks
        _checkAddresses();

        // check image
        bytes32 _imageId;
        _imageId = _checkImage(_imageId, imageIdIndex);

        // verify input
        __verify(journalEntry, commitment, seal, _imageId);
    }

    /**
     * @notice Verifies an input on an extension chain
     * @param journalEntry the risc0 journal entry
     * @param seal the risc0 seal
     * @param imageId the risc0 imageId
     */
    function _verifyInput(bytes calldata journalEntry, bytes calldata seal, bytes32 imageId) internal virtual {
        // generic checks
        _checkAddresses();

        // check image
        _checkImage(imageId, 0);

        // verify input
        verifier.verify(seal, imageId, sha256(journalEntry));
    }

    /**
     * @notice Verifies an input
     * @param journalEntry the risc0 journal entry
     * @param commitment the risc0 journal comittment
     * @param seal the risc0 seal
     * @param imageId the risc0 imageId
     */
    function _verifyInput(
        bytes calldata journalEntry,
        Steel.Commitment memory commitment,
        bytes calldata seal,
        bytes32 imageId
    ) internal virtual {
        // generic checks
        _checkAddresses();

        // check image
        _checkImage(imageId, 0);

        // verify input
        __verify(journalEntry, commitment, seal, imageId);
    }

    /**
     * @notice Batch verifies inputs
     * @param list the batch entry for risc0 parameters
     */
    function _verifyBatchInput(VerifierBatchData calldata list) internal virtual {
        // generic checks
        _checkAddresses();

        // batch checks
        require(list.journalEntries.length == list.commitments.length, ZkVerifier_InputNotValid());
        require(list.commitments.length == list.seals.length, ZkVerifier_InputNotValid());
        require(list.seals.length == list.imageIds.length, ZkVerifier_InputNotValid());
        require(list.imageIds.length == list.imageIdIndexes.length, ZkVerifier_InputNotValid());

        uint256 len = list.commitments.length;
        for (uint256 i; i < len; i++) {
            bytes32 _imageId = list.imageIds[i];

            // check image
            _imageId = _checkImage(_imageId, list.imageIdIndexes[i]);

            // verify input
            __verify(list.journalEntries[i], list.commitments[i], list.seals[i], _imageId);
        }
    }

    // ----------- PRIVATE ------------
    function _checkImage(bytes32 imageId, uint256 _imageIndex) private view returns (bytes32) {
        /**
         *  @dev if imageId was provided, check it directly; otherwise get it by index
         */
        if (imageId != bytes32(0)) {
            require(verifierImageRegistry.isActive(imageId), ZkVerifier_ImageNotValid());
        } else {
            imageId = verifierImageRegistry.getImageForIndex(_imageIndex);
            require(verifierImageRegistry.isActive(imageId), ZkVerifier_ImageNotValid());
        }
        return imageId;
    }

    function _checkAddresses() private view {
        require(address(verifier) != address(0), ZkVerifier_VerifierNotSet());
        require(address(verifierImageRegistry) != address(0), ZkVerifier_VerifierImageRegistryNotSet());
    }

    function __verify(
        bytes calldata journalEntry,
        Steel.Commitment memory commitment,
        bytes calldata seal,
        bytes32 imageId
    ) private {
        require(!_validatedCommitments[commitment.id], ZkVerifier_AlreadyVerified(commitment.id));
        require(Steel.validateCommitment(commitment), ZkVerifier_InvalidCommitment(commitment.id));

        verifier.verify(seal, imageId, sha256(journalEntry));

        _validatedCommitments[commitment.id] = true;
    }
}
