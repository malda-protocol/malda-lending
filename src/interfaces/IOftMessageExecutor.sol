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

/// @title IOftMessageExecutor
/// @author
/// @notice Interface for OFT message executor helpers used via delegatecall by bridges.
interface IOftMessageExecutor {
    /// @notice Executes an OFT send on the bridge contract (OFT) and returns the LayerZero receipt.
    /// @param underlying The underlying token address.
    /// @param bridgeContract The bridge contract used for the OFT send.
    /// @param params LayerZero send parameters.
    /// @param fees LayerZero messaging fees.
    /// @param rebalancer The rebalancer address providing the funds.
    /// @param refundAddress Address that receives any excess native fee refund.
    /// @return receipt The LayerZero messaging receipt containing the message GUID.
    function executeSend(
        address underlying,
        address bridgeContract,
        SendParam calldata params,
        MessagingFee calldata fees,
        address rebalancer,
        address refundAddress
    ) external payable returns (MessagingReceipt memory receipt);

    /// @notice Fallback route in case lzCompose does not execute; unwraps/forwards funds to the market.
    /// @param market The market address.
    /// @param underlying The underlying token address.
    /// @param bridgeContract The bridge contract used for OFT operations.
    function processUncomposed(address market, address underlying, address bridgeContract) external payable;

    /// @notice Executes compose handling for a market.
    /// @param market The market address.
    /// @param underlying The underlying token address.
    /// @param bridgeContract The bridge contract used for OFT operations.
    function executeCompose(address market, address underlying, address bridgeContract) external payable;
}
