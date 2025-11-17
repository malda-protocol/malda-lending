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
import {SendParam, MessagingFee, ILayerZeroOFT} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

contract rsEthOftMessageExecutor is BaseOftMessageExecutor {
    error Executor_DifferentInnerToken();

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
            try ILayerZeroOFTWrapper(bridgeContract).allowedTokens(underlying) returns (bool ok) {
                if (!ok) revert Executor_DifferentInnerToken();
            } catch {
                revert Executor_NoOft();
            }

            _approve(underlying, bridgeContract, params.amountLD);
            ILayerZeroOFTWrapper(bridgeContract).deposit(underlying, params.amountLD);

            _verifyMinted(bridgeContract, params.amountLD);
        }

        return _sendOFT(bridgeContract, params, fees, refundAddress);
    }
}
