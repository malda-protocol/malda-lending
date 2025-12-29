// Copyright (c) 2025 Merge Layers Inc.
//
// This source code is licensed under the Business Source License 1.1
// (the "License"); you may not use this file except in compliance with the
// License. You may obtain a copy of the License at
//
//     https://github.com/malda-protocol/malda-lending/blob/main/LICENSE-BSL
//
// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

import {BaseOftMessageExecutor} from "./BaseOftMessageExecutor.sol";
import {ILayerZeroOFTWrapper} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {SendParam, MessagingFee} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

/// @title rsEthOftMessageExecutor
/// @author Malda Protocol
/// @notice OFT message executor for rsETH-like wrapper OFTs where the underlying may wrap/unwrap into an inner token.
contract rsEthOftMessageExecutor is BaseOftMessageExecutor {
    /// @notice Thrown when the bridge contract is not an allowed inner token for the wrapper.
    error Executor_DifferentInnerToken();

    /// @notice Pulls tokens from the rebalancer, unwraps if needed, then sends via OFT.
    /// @param underlying The underlying token address.
    /// @param bridgeContract The bridge contract used for the OFT send (may differ from underlying).
    /// @param params LayerZero send parameters.
    /// @param fees LayerZero messaging fees.
    /// @param rebalancer The rebalancer address providing the funds.
    /// @param refundAddress Address that receives any excess native fee refund.
    /// @return MessagingReceipt LayerZero receipt containing the message GUID.
    function executeSend(
        address underlying,
        address bridgeContract,
        SendParam calldata params,
        MessagingFee calldata fees,
        address rebalancer,
        address refundAddress
    ) external payable override returns (MessagingReceipt memory) {
        _pullFromRebalancer(underlying, params.amountLD, rebalancer);

        if (bridgeContract != underlying) {
            try ILayerZeroOFTWrapper(underlying).allowedTokens(bridgeContract) returns (bool ok) {
                if (!ok) revert Executor_DifferentInnerToken();
            } catch {
                revert Executor_NoOft();
            }

            _approve(underlying, bridgeContract, params.amountLD);
            ILayerZeroOFTWrapper(underlying).withdraw(bridgeContract, params.amountLD);

            _verifyMinted(bridgeContract, params.amountLD);
        }

        return _sendOFT(bridgeContract, params, fees, refundAddress);
    }
}
