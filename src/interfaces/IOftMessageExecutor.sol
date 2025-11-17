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

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/


import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {SendParam, MessagingFee} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

interface IOftMessageExecutor {
    function executeSend(
        address underlying,
        address bridgeContract,
        SendParam calldata params,
        MessagingFee calldata fees,
        address rebalancer,
        address refundAddress
    ) external payable returns (MessagingReceipt memory);

    /// @dev fallback route in case lzCompose does not execute
    function processUncomposed(
        address market,
        address underlying,
        address bridgeContract
    ) external payable;

    function executeCompose(
        address market,
        address underlying,
        address bridgeContract
    ) external payable;
}