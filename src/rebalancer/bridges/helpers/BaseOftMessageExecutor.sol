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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {SafeApprove} from "src/libraries/SafeApprove.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {MessagingReceipt} from "src/interfaces/external/layerzero/v2/ILayerZeroEndpointV2.sol";
import {SendParam, MessagingFee, ILayerZeroOFT, ILayerZeroOFTWrapper} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

import {IOftMessageExecutor} from "src/interfaces/IOftMessageExecutor.sol";

abstract contract BaseOftMessageExecutor is IOftMessageExecutor {
    using SafeERC20 for IERC20;

    // ---------------- ERRORS ----------------
    
    error Executor_NoOft();
    error Executor_AmountMismatch();
    error Executor_WrongUnderlying();

    // ---------------- PUBLIC HELPERS ----------------
    function processUncomposed(
        address market,
        address underlying,
        address bridgeContract
    ) external virtual payable override {
        _fallbackToUnderlying(market, underlying, bridgeContract);
    }

    function executeCompose(
        address market,
        address underlying,
        address bridgeContract
    ) external virtual payable override {
        // same behavior as the manual fallback: unwrap OFT (if needed) and send underlying to the market.
        _fallbackToUnderlying(market, underlying, bridgeContract);
    }

    // ---------------- INTERNAL HELPERS ----------------
    function _pullFromRebalancer(
        address underlying,
        uint256 amount,
        address rebalancer
    ) internal {
        IERC20(underlying).safeTransferFrom(rebalancer, address(this), amount);
    }

    function _approve(address token, address spender, uint256 amount) internal {
        SafeApprove.safeApprove(token, spender, amount);
    }

    function _sendOFT(
        address oft,
        SendParam calldata params,
        MessagingFee calldata fees,
        address refundAddress
    ) internal returns (MessagingReceipt memory receipt) {
        (receipt,) = ILayerZeroOFT(oft).send{value: fees.nativeFee}(params, fees, refundAddress);
    }

    function _verifyMinted(address oft, uint256 required) internal view {
        uint256 bal = IERC20(oft).balanceOf(address(this));
        if (bal < required) revert Executor_AmountMismatch();
    }

    function _fallbackToUnderlying(
        address market,
        address underlying,
        address bridgeContract
    ) internal {
        if (bridgeContract == underlying) {
            uint256 bal = IERC20(underlying).balanceOf(address(this));
            IERC20(underlying).safeTransfer(market, bal);
            return;
        }

        uint256 oftBal = IERC20(bridgeContract).balanceOf(address(this));
        if (oftBal == 0) return;

        _approve(bridgeContract, underlying, oftBal);
        ILayerZeroOFTWrapper(underlying).deposit(bridgeContract, oftBal);

        uint256 uBal = IERC20(underlying).balanceOf(address(this));
        IERC20(underlying).safeTransfer(market, uBal);
    }
}
