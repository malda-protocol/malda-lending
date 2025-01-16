// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {IRoles} from "src/interfaces/IRoles.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";

/**
 * @title BatchSubmitter
 * @notice Allows batching of outHere operations on the extension chain
 */
contract BatchSubmitter is ZkVerifier {
    error BatchSubmitter_CallerNotAllowed();
    error BatchSubmitter_JournalNotValid();
    error BatchSubmitter_InvalidSelector();

    event BatchProcessFailed(bytes journal, bytes reason);

    /**
     * @notice The roles contract for access control
     */
    IRoles public immutable rolesOperator;

    // Function selectors for supported operations
    bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector;
    bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector;
    bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector;

    constructor(address _roles, address zkVerifier_) {
        rolesOperator = IRoles(_roles);
        ZkVerifier.initialize(zkVerifier_);
    }

    /**
     * @notice Execute multiple operations in a single transaction
     * @param journalData The encoded journal data
     * @param seal The seal data for verification
     * @param mTokens Array of mToken addresses
     * @param amounts Array of amounts for each operation
     * @param selectors Array of function selectors for each operation
     * @param startIndex Start index for processing journals
     * @param endIndex End index for processing journals (exclusive)
     */
    function batchProcess(
        bytes calldata journalData,
        bytes calldata seal,
        address[] calldata mTokens,
        uint256[] calldata amounts,
        bytes4[] calldata selectors,
        uint256 startIndex,
        uint256 endIndex
    ) external {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_FORWARDER())) {
            revert BatchSubmitter_CallerNotAllowed();
        }

        _verifyProof(journalData, seal);

        bytes[] memory journals = abi.decode(journalData, (bytes[]));

        for (uint256 i = startIndex; i < endIndex;) {
            bytes[] memory singleJournal = new bytes[](1);
            singleJournal[0] = journals[i];
            bytes memory encodedJournal = abi.encode(singleJournal);

            uint256[] memory singleAmount = new uint256[](1);
            singleAmount[0] = amounts[i];

            bytes4 selector = selectors[i];
            
            if (selector == MINT_SELECTOR) {
                try ImErc20Host(mTokens[i]).mintExternal(
                    encodedJournal,
                    "",
                    singleAmount
                ) {} catch (bytes memory reason) {
                    emit BatchProcessFailed(journals[i], reason);
                }
            } else if (selector == REPAY_SELECTOR) {
                try ImErc20Host(mTokens[i]).repayExternal(
                    encodedJournal,
                    "",
                    singleAmount
                ) {} catch (bytes memory reason) {
                    emit BatchProcessFailed(journals[i], reason);
                }
            } else if (selector == OUT_HERE_SELECTOR) {
                try ImTokenGateway(mTokens[i]).outHere(
                    encodedJournal,
                    "",
                    singleAmount
                ) {} catch (bytes memory reason) {
                    emit BatchProcessFailed(journals[i], reason);
                }
            } else {
                revert BatchSubmitter_InvalidSelector();
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

        _verifyInput(journalData, seal);
    }
} 