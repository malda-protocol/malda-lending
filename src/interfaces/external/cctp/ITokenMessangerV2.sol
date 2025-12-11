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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface ITokenMessangerV2 {
    /**
     * @notice Deposits and burns tokens from sender to be minted on destination domain.
     * Emits a `DepositForBurn` event.
     * @dev reverts if:
     * - `hookData` is zero-length
     * - `burnToken` is not supported
     * - `destinationDomain` has no TokenMessenger registered
     * - transferFrom() reverts. For example, if sender's burnToken balance or approved allowance
     * to this contract is less than `amount`.
     * - burn() reverts. For example, if `amount` is 0.
     * - maxFee is greater than or equal to `amount`.
     * - MessageTransmitterV2#sendMessage reverts.
     * @param amount amount of tokens to burn
     * @param destinationDomain destination domain to receive message on
     * @param mintRecipient address of mint recipient on destination domain, as bytes32
     * @param burnToken token to burn `amount` of, on local domain
     * @param destinationCaller authorized caller on the destination domain, as bytes32. If equal to bytes32(0),
     * any address can broadcast the message.
     * @param maxFee maximum fee to pay on the destination domain, specified in units of burnToken
     * @param hookData hook data to append to burn message for interpretation on destination domain
     */
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external;
}