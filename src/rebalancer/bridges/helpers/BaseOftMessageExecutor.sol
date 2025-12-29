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
import {
    SendParam,
    MessagingFee,
    ILayerZeroOFT,
    ILayerZeroOFTWrapper
} from "src/interfaces/external/layerzero/v2/ILayerZeroOFT.sol";

import {IOftMessageExecutor} from "src/interfaces/IOftMessageExecutor.sol";

/// @title BaseOftMessageExecutor
/// @author Malda Protocol
/// @notice Base implementation for OFT message executors used via delegatecall by bridges.
abstract contract BaseOftMessageExecutor is IOftMessageExecutor {
    using SafeERC20 for IERC20;

    // ---------------- ERRORS ----------------

    error Executor_NoOft();
    error Executor_AmountMismatch();
    error Executor_WrongUnderlying();
    error Executor_NotRebalancer();

    // ---------------- PUBLIC HELPERS ----------------

    /// @notice Processes stored/uncomposed messages for a market by falling back to underlying.
    /// @param market The market address.
    /// @param underlying The underlying token address.
    /// @param bridgeContract The bridge contract used for OFT operations.
    function processUncomposed(address market, address underlying, address bridgeContract)
        external
        payable
        virtual
        override
    {
        _fallbackToUnderlying(market, underlying, bridgeContract);
    }

    /// @notice Executes a compose step for a market by falling back to underlying.
    /// @param market The market address.
    /// @param underlying The underlying token address.
    /// @param bridgeContract The bridge contract used for OFT operations.
    function executeCompose(address market, address underlying, address bridgeContract)
        external
        payable
        virtual
        override
    {
        _fallbackToUnderlying(market, underlying, bridgeContract);
    }

    // ---------------- INTERNAL HELPERS (NON-VIEW) ----------------

    function _pullFromRebalancer(address underlying, uint256 amount, address rebalancer) internal {
        if (rebalancer != msg.sender) revert Executor_NotRebalancer();
        IERC20(underlying).safeTransferFrom(rebalancer, address(this), amount);
    }

    function _approve(address token, address spender, uint256 amount) internal {
        SafeApprove.safeApprove(token, spender, amount);
    }

    function _sendOFT(address oft, SendParam calldata params, MessagingFee calldata fees, address refundAddress)
        internal
        returns (MessagingReceipt memory receipt)
    {
        // solhint-disable-next-line check-send-result
        (receipt,) = ILayerZeroOFT(oft).send{value: fees.nativeFee}(params, fees, refundAddress);
    }

    function _fallbackToUnderlying(address market, address underlying, address bridgeContract) internal {
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

    // ---------------- INTERNAL HELPERS (VIEW) ----------------

    function _verifyMinted(address oft, uint256 required) internal view {
        uint256 bal = IERC20(oft).balanceOf(address(this));
        if (bal < required) revert Executor_AmountMismatch();
    }
}
