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
// This file contains code derived from or inspired by Compound V2,
// originally licensed under the BSD 3-Clause License. See LICENSE-COMPOUND-V2
// for original license terms and attributions.

// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IRoles} from "src/interfaces/IRoles.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
import {ImErc20Host} from "src/interfaces/ImErc20Host.sol";
import {IZkVerifier} from "src/verifier/ZkVerifier.sol";

/// @title BatchSubmitter
/// @author Merge Layers Inc.
/// @notice Contract for batch processing multiple operations
contract BatchSubmitter is Ownable {
    /// @notice Parameters used to process a batch of operations
    /// @param receivers Funds receivers
    /// @param journalData Encoded journal data
    /// @param seal Seal data for verification
    /// @param mTokens Array of mToken addresses
    /// @param amounts Array of amounts for each operation
    /// @param minAmountsOut Array of minimum output amounts
    /// @param selectors Array of function selectors for each operation
    /// @param initHashes Array of initial hashes for journals
    /// @param startIndex Start index for processing journals
    /// @param userToLiquidate Array of users to liquidate (for liquidateExternal operations)
    /// @param collateral Array of collateral addresses (for liquidateExternal operations)
    struct BatchProcessMsg {
        address[] receivers;
        bytes journalData;
        bytes seal;
        address[] mTokens;
        uint256[] amounts;
        uint256[] minAmountsOut;
        bytes4[] selectors;
        bytes32[] initHashes;
        uint256 startIndex;
        address[] userToLiquidate;
        address[] collateral;
    }

    // ----------- CONSTANTS -----------
    /// @notice The function selector for the supported `mintExternal` operation
    bytes4 internal constant MINT_SELECTOR = ImErc20Host.mintExternal.selector;

    /// @notice The function selector for the supported `repayExternal` operation
    bytes4 internal constant REPAY_SELECTOR = ImErc20Host.repayExternal.selector;

    /// @notice The function selector for the supported `outHere` operation
    bytes4 internal constant OUT_HERE_SELECTOR = ImTokenGateway.outHere.selector;

    /// @notice The function selector for the supported `liquidateExternal` operation
    bytes4 internal constant LIQUIDATE_SELECTOR = ImErc20Host.liquidateExternal.selector;

    // ----------- IMMUTABLES -----------
    /// @notice The roles contract for access control
    IRoles public immutable ROLES_OPERATOR;

    // ----------- STATE VARIABLES -----------
    /// @notice The ZkVerifier contract
    IZkVerifier public verifier;

    // ----------- EVENTS -----------
    /// @notice Event emitted when batch process fails
    /// @param initHash The initialization hash
    /// @param receiver The receiver address
    /// @param mToken The mToken address
    /// @param amount The amount
    /// @param minAmountOut The minimum amount out
    /// @param selector The function selector
    /// @param reason The failure reason
    event BatchProcessFailed(
        bytes32 initHash,
        address receiver,
        address mToken,
        uint256 amount,
        uint256 minAmountOut,
        bytes4 selector,
        bytes reason
    );

    /// @notice Event emitted when batch process succeeds
    /// @param initHash The initialization hash
    /// @param receiver The receiver address
    /// @param mToken The mToken address
    /// @param amount The amount
    /// @param minAmountOut The minimum amount out
    /// @param selector The function selector
    event BatchProcessSuccess(
        bytes32 initHash, address receiver, address mToken, uint256 amount, uint256 minAmountOut, bytes4 selector
    );

    /// @notice Event emitted when ZkVerifier is updated
    /// @param oldVerifier The old verifier address
    /// @param newVerifier The new verifier address
    event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);

    // ----------- ERRORS -----------

    /// @notice Error thrown when caller is not allowed
    error BatchSubmitter_CallerNotAllowed();

    /// @notice Error thrown when journal is not valid
    error BatchSubmitter_JournalNotValid();

    /// @notice Error thrown when selector is invalid
    error BatchSubmitter_InvalidSelector();

    /// @notice Error thrown when address is not valid
    error BatchSubmitter_AddressNotValid();

    /// @notice Constructor
    /// @param _roles The roles contract address
    /// @param _zkVerifier The ZkVerifier contract address
    /// @param owner_ The owner address
    constructor(address _roles, address _zkVerifier, address owner_) Ownable(owner_) {
        require(_roles != address(0), BatchSubmitter_AddressNotValid());
        require(_zkVerifier != address(0), BatchSubmitter_AddressNotValid());
        ROLES_OPERATOR = IRoles(_roles);
        verifier = IZkVerifier(_zkVerifier);
    }

    // ----------- OWNER ------------
    /// @notice Updates IZkVerifier address
    /// @param _zkVerifier the verifier address
    function updateZkVerifier(address _zkVerifier) external onlyOwner {
        require(_zkVerifier != address(0), BatchSubmitter_AddressNotValid());
        emit ZkVerifierUpdated(address(verifier), _zkVerifier);
        verifier = IZkVerifier(_zkVerifier);
    }

    // ----------- PUBLIC ------------
    // slither-disable-start cyclomatic-complexity
    /// @notice Execute multiple operations in a single transaction
    /// @param data The batch process message data
    function batchProcess(BatchProcessMsg calldata data) external {
        // Requirements: the caller must have permission to forward proof
        require(
            ROLES_OPERATOR.isAllowedFor(msg.sender, ROLES_OPERATOR.PROOF_FORWARDER()), BatchSubmitter_CallerNotAllowed()
        );

        // Interactions: verify the proof
        _verifyProof(data.journalData, data.seal);

        // Decode the dynamic array of journals.
        bytes[] memory journals = abi.decode(data.journalData, (bytes[]));

        uint256 length = data.initHashes.length;
        for (uint256 i = 0; i < length; i++) {
            bytes[] memory singleJournal = new bytes[](1);
            singleJournal[0] = journals[data.startIndex + i];

            uint256[] memory singleAmount = new uint256[](1);
            singleAmount[0] = data.amounts[i];

            bytes4 selector = data.selectors[i];
            bytes memory encodedJournal = abi.encode(singleJournal);
            if (selector == MINT_SELECTOR) {
                uint256[] memory singleMinAmounts = new uint256[](1);
                singleMinAmounts[0] = data.minAmountsOut[i];

                // Interactions: mint the external
                try ImErc20Host(data.mTokens[i])
                    .mintExternal(encodedJournal, "", singleAmount, singleMinAmounts, data.receivers[i]) {
                    // Events: if successfully minted, emit the batch process success event
                    emit BatchProcessSuccess(
                        data.initHashes[i],
                        data.receivers[i],
                        data.mTokens[i],
                        data.amounts[i],
                        data.minAmountsOut[i],
                        selector
                    );
                } catch (bytes memory reason) {
                    // Events: if failed to mint, emit the batch process failed event
                    emit BatchProcessFailed(
                        data.initHashes[i],
                        data.receivers[i],
                        data.mTokens[i],
                        data.amounts[i],
                        data.minAmountsOut[i],
                        selector,
                        reason
                    );
                }
            } else if (selector == REPAY_SELECTOR) {
                // Interactions: repay the external
                try ImErc20Host(data.mTokens[i]).repayExternal(encodedJournal, "", singleAmount, data.receivers[i]) {
                    // Events: if successfully repaid, emit the batch process success event
                    emit BatchProcessSuccess(
                        data.initHashes[i],
                        data.receivers[i],
                        data.mTokens[i],
                        data.amounts[i],
                        data.minAmountsOut[i],
                        selector
                    );
                } catch (bytes memory reason) {
                    // Events: if failed to repay, emit the batch process failed event
                    emit BatchProcessFailed(
                        data.initHashes[i],
                        data.receivers[i],
                        data.mTokens[i],
                        data.amounts[i],
                        data.minAmountsOut[i],
                        selector,
                        reason
                    );
                }
            } else if (selector == OUT_HERE_SELECTOR) {
                // Interactions: out here
                try ImTokenGateway(data.mTokens[i]).outHere(encodedJournal, "", singleAmount, data.receivers[i]) {
                    // Events: if successfully out here, emit the batch process success event
                    emit BatchProcessSuccess(
                        data.initHashes[i],
                        data.receivers[i],
                        data.mTokens[i],
                        data.amounts[i],
                        data.minAmountsOut[i],
                        selector
                    );
                } catch (bytes memory reason) {
                    // Events: if failed to out here, emit the batch process failed event
                    emit BatchProcessFailed(
                        data.initHashes[i],
                        data.receivers[i],
                        data.mTokens[i],
                        data.amounts[i],
                        data.minAmountsOut[i],
                        selector,
                        reason
                    );
                }
            } else if (selector == LIQUIDATE_SELECTOR) {
                address[] memory singleUserToLiquidate = new address[](1);
                singleUserToLiquidate[0] = data.userToLiquidate[i];

                address[] memory singleCollateral = new address[](1);
                singleCollateral[0] = data.collateral[i];

                // Interactions: liquidate the external
                try ImErc20Host(data.mTokens[i])
                    .liquidateExternal(
                        encodedJournal, "", singleUserToLiquidate, singleAmount, singleCollateral, data.receivers[i]
                    ) {
                    // Events: if successfully liquidated, emit the batch process success event
                    emit BatchProcessSuccess(
                        data.initHashes[i],
                        data.receivers[i],
                        data.mTokens[i],
                        data.amounts[i],
                        data.minAmountsOut[i],
                        selector
                    );
                } catch (bytes memory reason) {
                    // Interactions: if liquidate fails, try mint as fallback
                    try ImErc20Host(data.mTokens[i])
                        .mintExternal(encodedJournal, "", singleAmount, new uint256[](1), data.receivers[i]) {
                        // Events: if successfully minted, emit the batch process success event
                        emit BatchProcessSuccess(
                            data.initHashes[i],
                            data.receivers[i],
                            data.mTokens[i],
                            data.amounts[i],
                            data.minAmountsOut[i],
                            MINT_SELECTOR
                        );
                    } catch (bytes memory) {
                        // Events: if failed to mint, emit the batch process failed event
                        emit BatchProcessFailed(
                            data.initHashes[i], data.receivers[i], data.mTokens[i], data.amounts[i], 0, selector, reason
                        );
                    }
                }
            } else {
                revert BatchSubmitter_InvalidSelector();
            }
        }
    }

    // slither-disable-end cyclomatic-complexity

    /// @notice Verifies the proof using ZkVerifier
    /// @param journalData The journal data to verify
    /// @param seal The seal data for verification
    function _verifyProof(bytes calldata journalData, bytes calldata seal) private view {
        // Requirements: the journal data is not empty
        require(journalData.length > 0, BatchSubmitter_JournalNotValid());

        // Interactions: verify the proof using the ZkVerifier contract
        verifier.verifyInput(journalData, seal);
    }
}
