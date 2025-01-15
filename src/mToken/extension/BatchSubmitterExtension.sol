// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {mTokenGateway} from "./mTokenGateway.sol";
import {IRoles} from "src/interfaces/IRoles.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";

/**
 * @title BatchSubmitterExtension
 * @notice Allows batching of outHere operations on the extension chain
 */
contract BatchSubmitterExtension is ZkVerifier {
    error BatchSubmitterExtension_CallerNotAllowed();
    error BatchSubmitterExtension_JournalNotValid();
    error BatchSubmitterExtension_LengthMismatch();

    event BatchOutHereResult(address indexed mToken, bool success, bytes data);

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
     * @param mTokens Array of mToken addresses
     * @param amounts Array of amounts for each operation
     */
    function batchOutHere(
        bytes calldata journalData,
        address[] calldata mTokens,
        uint256[] calldata amounts
    ) external {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_FORWARDER())) {
            revert BatchSubmitterExtension_CallerNotAllowed();
        }

        // Verify the proof
        _verifyProof(journalData, seal);

        // Decode journal data into array of bytes
        bytes[] memory journals = abi.decode(journalData, (bytes[]));
        
        uint256 length = mTokens.length;
        if (length != journals.length || length != amounts.length) {
            revert BatchSubmitterExtension_LengthMismatch();
        }

        for (uint256 i = 0; i < length;) {
            // Create single-element array and encode it
            bytes[] memory singleJournal = new bytes[](1);
            singleJournal[0] = journals[i];
            bytes memory encodedJournal = abi.encode(singleJournal);

            try mTokenGateway(mTokens[i]).outHere(
                encodedJournal,
                "",
                amounts
            ) {
                emit BatchOutHereResult(mTokens[i], true, "");
            } catch (bytes memory reason) {
                emit BatchOutHereResult(mTokens[i], false, reason);
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Verifies the proof using ZkVerifier
     * @param journalData The journal data to verify
     * @param seal The seal data for verification
     */
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private {
        if (journalData.length == 0) {
            revert BatchSubmitterExtension_JournalNotValid();
        }

        // verify it using the ZkVerifier contract
        _verifyInput(journalData, seal);
    }
} 