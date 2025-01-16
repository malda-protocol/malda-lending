// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {ZkVerifier} from "src/verifier/ZkVerifier.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";

contract BatchSubmitter is ZkVerifier, Ownable {
    error BatchSubmitter_CallerNotAllowed();
    error BatchSubmitter_JournalNotValid();
    error BatchSubmitter_InvalidSelector();

    event BatchProcessFailed(bytes journal, bytes reason);

    /**
     * @notice The roles contract for access control
     */
    IRoles public immutable rolesOperator;

    /**
     * receiver Funds receiver/performed on
     * journalData The encoded journal data
     * seal The seal data for verification
     * mTokens Array of mToken addresses
     * amounts Array of amounts for each operation
     * selectors Array of function selectors for each operation
     * startIndex Start index for processing journals
     * endIndex End index for processing journals (exclusive)
     */
    struct BatchProcessMsg {
        address receiver;
        bytes journalData;
        bytes seal;
        address[] mTokens;
        uint256[] amounts;
        bytes4[] selectors;
        uint256 startIndex;
        uint256 endIndex;
    }

    // Function selectors for supported operations
    bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector;
    bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector;
    bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector;

    error BatchSubmitter_LengthMismatch();

    constructor(address _roles, address zkVerifier_, address _owner) Ownable(_owner) {
        rolesOperator = IRoles(_roles);
        ZkVerifier.initialize(zkVerifier_);
    }

    // ----------- OWNER ------------
    /**
     * @notice Sets the _risc0Verifier address
     * @param _risc0Verifier the new IRiscZeroVerifier address
     */
    function setVerifier(address _risc0Verifier) external onlyOwner {
        _setVerifier(_risc0Verifier);
    }

    /**
     * @notice Sets the image id
     * @param _imageId the new image id
     */
    function setImageId(bytes32 _imageId) external onlyOwner {
        _setImageId(_imageId);
    }

    // ----------- PUBLIC ------------
    /**
     * @notice Execute multiple operations in a single transaction
     */
    function batchProcess(BatchProcessMsg calldata data) external {
        if (!rolesOperator.isAllowedFor(msg.sender, rolesOperator.PROOF_FORWARDER())) {
            revert BatchSubmitter_CallerNotAllowed();
        }

        _verifyProof(data.journalData, data.seal);

        bytes[] memory journals = abi.decode(data.journalData, (bytes[]));
        uint256 length = journals.length;

        require(length == data.mTokens.length, BatchSubmitter_LengthMismatch());
        require(length == data.amounts.length, BatchSubmitter_LengthMismatch());
        require(length == data.selectors.length, BatchSubmitter_LengthMismatch());

        for (uint256 i = data.startIndex; i < data.endIndex;) {
            bytes[] memory singleJournal = new bytes[](1);
            singleJournal[0] = journals[i];

            uint256[] memory singleAmount = new uint256[](1);
            singleAmount[0] = data.amounts[i];

            bytes4 selector = data.selectors[i];
            bytes memory encodedJournal = abi.encode(singleJournal);
            if (selector == MINT_SELECTOR) {
                try ImErc20Host(data.mTokens[i]).mintExternal(encodedJournal, "", singleAmount, data.receiver) {}
                catch (bytes memory reason) {
                    emit BatchProcessFailed(journals[i], reason);
                }
            } else if (selector == REPAY_SELECTOR) {
                try ImErc20Host(data.mTokens[i]).repayExternal(encodedJournal, "", singleAmount, data.receiver) {}
                catch (bytes memory reason) {
                    emit BatchProcessFailed(journals[i], reason);
                }
            } else if (selector == OUT_HERE_SELECTOR) {
                try ImTokenGateway(data.mTokens[i]).outHere(encodedJournal, "", singleAmount, data.receiver) {}
                catch (bytes memory reason) {
                    emit BatchProcessFailed(journals[i], reason);
                }
            } else {
                revert BatchSubmitter_InvalidSelector();
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
            revert BatchSubmitter_JournalNotValid();
        }

        _verifyInput(journalData, seal);
    }
}
