// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IRoles} from "src/interfaces/IRoles.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

/**
 * @title BatchSubmitter
 * @notice Allows batching of outHere operations on the extension chain
 */
contract BatchSubmitter is ZkVerifier {
    error BatchSubmitter_CallerNotAllowed();
    error BatchSubmitter_JournalNotValid();

    event BatchOutHereFailed(bytes journal, bytes reason);

    /**
     * @notice The roles contract for access control
     */
    IRoles public immutable rolesOperator;

    constructor(address _roles, address zkVerifier_) {
        rolesOperator = IRoles(_roles);
        // Initialize the ZkVerifier
        ZkVerifier.initialize(zkVerifier_);
    }

    /**
     * @notice Execute multiple outHere operations in a single transaction
     * @param journalData The encoded journal data
     * @param seal The seal data for verification
     * @param mTokens Array of mToken addresses
     * @param amounts Array of amounts for each operation
     * @param startIndex Start index for processing journals
     * @param endIndex End index for processing journals (exclusive)
     */
    function batchOutHere(
        bytes calldata journalData,
        bytes calldata seal,
        address[] calldata mTokens,
        uint256[] calldata amounts,
        uint256 startIndex,
        uint256 endIndex
    ) external {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_FORWARDER())) {
            revert BatchSubmitter_CallerNotAllowed();
        }

        // Verify the proof
        _verifyProof(journalData, seal);

        // Decode journal data into array of bytes
        bytes[] memory journals = abi.decode(journalData, (bytes[]));


        for (uint256 i = startIndex; i < endIndex;) {
            // Create single-element array and encode it
            bytes[] memory singleJournal = new bytes[](1);
            singleJournal[0] = journals[i];
            bytes memory encodedJournal = abi.encode(singleJournal);

            // Create single-element array for amount
            uint256[] memory singleAmount = new uint256[](1);
            singleAmount[0] = amounts[i];

            try ImTokenGateway(mTokens[i]).outHere(
                encodedJournal,
                "",
                singleAmount
            ) {} catch (bytes memory reason) {
                emit BatchOutHereFailed(journals[i], reason);
            }

            unchecked { ++i; }
        }
    }

    /**
     * @notice Verifies the proof using ZkVerifier
     * @param journalData The journal data to verify
     * @param seal The seal data for verification
     */
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private {
        if (journalData.length == 0) {
            revert BatchSubmitter_JournalNotValid();
        }

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal);
    }
} 