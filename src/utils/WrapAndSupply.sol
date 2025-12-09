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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ImErc20} from "src/interfaces/ImErc20.sol";
import {ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";

/// @title Wrapped native token interface
/// @author Malda Protocol
/// @notice Minimal interface used to wrap/unwrap native tokens (e.g., WETH)
interface IWrappedNative {
    /// @notice Wraps native ETH into WETH
    function deposit() external payable;

    /// @notice Transfers wrapped native tokens
    /// @param to Receiver address
    /// @param value Amount to transfer
    /// @return Whether the transfer succeeded
    function transfer(address to, uint256 value) external returns (bool);

    /// @notice Unwraps wrapped native tokens back to the native coin
    /// @param amount Amount to unwrap
    function withdraw(uint256 amount) external;
}

/// @title WrapAndSupply
/// @author Malda Protocol
/// @notice Wraps native coins and supplies to host or extension markets in a single call.
contract WrapAndSupply {
    /// @notice The wrapped native coin contract
    IWrappedNative public immutable WRAPPED_NATIVE;

    // ----------- EVENTS ------------
    /// @notice Emitted when native assets are wrapped and supplied to a market
    /// @param sender The caller providing native funds
    /// @param receiver The account receiving the minted mTokens
    /// @param market The market that received the wrapped assets
    /// @param amount The amount of native coin wrapped and supplied
    event WrappedAndSupplied(address indexed sender, address indexed receiver, address indexed market, uint256 amount);

    // ----------- ERRORS ------------
    error WrapAndSupply_AddressNotValid();
    error WrapAndSupply_AmountNotValid();

    /// @notice Initializes the helper with the wrapped native token address
    /// @param _wrappedNative Wrapped native token (e.g., WETH) contract address
    constructor(address _wrappedNative) {
        // Requirements: wrapped native coin's address must not be zero
        require(_wrappedNative != address(0), WrapAndSupply_AddressNotValid());

        // Effects: set the wrapped native coin's contract address
        WRAPPED_NATIVE = IWrappedNative(_wrappedNative);
    }

    // ----------- PUBLIC ------------
    /// @notice Wraps a native coin into its wrapped version and supplies on a host market
    /// @param mToken The market address
    /// @param receiver The mToken receiver
    /// @param minAmount The minimum amount of mTokens expected
    function wrapAndSupplyOnHostMarket(address mToken, address receiver, uint256 minAmount) external payable {
        // Requirements: the underlying must be the wrapped native coin
        address underlying = ImTokenMinimal(mToken).underlying();
        require(underlying == address(WRAPPED_NATIVE), WrapAndSupply_AddressNotValid());

        // @audit-question why not check other addresses for zero address, especially the receiver?

        // Interactions: wrap the native coin into its wrapped version
        uint256 amount = msg.value;
        _wrap(amount);

        // @audit-question why not use safeApprove?
        // Interactions: approve the underlying to the market
        IERC20(underlying).approve(mToken, 0); // @audit-question why approve 0 first?
        IERC20(underlying).approve(mToken, amount);

        // Interactions: supply the underlying to the host market
        ImErc20(mToken).mint(amount, receiver, minAmount);

        // Events: emit the wrapped and supplied event
        emit WrappedAndSupplied(msg.sender, receiver, mToken, amount);
    }

    /// @notice Wraps a native coin into its wrapped version and supplies on an extension market
    /// @param mTokenGateway The extension market address
    /// @param receiver The receiver
    /// @param selector The host chain function selector
    function wrapAndSupplyOnExtensionMarket(address mTokenGateway, address receiver, bytes4 selector) external payable {
        // Requirements: the underlying must be the wrapped native coin
        address underlying = ImTokenGateway(mTokenGateway).underlying();
        require(underlying == address(WRAPPED_NATIVE), WrapAndSupply_AddressNotValid());

        // @audit-question why not check other addresses for zero address, especially the receiver?

        uint256 _gasFee = ImTokenGateway(mTokenGateway).gasFee();

        // Interactions: wrap the native coin into its wrapped version
        uint256 amount = msg.value - _gasFee;
        _wrap(amount);

        // Interactions: approve the underlying to the market
        IERC20(underlying).approve(mTokenGateway, 0); // @audit-question why approve 0 first?
        IERC20(underlying).approve(mTokenGateway, amount);

        // Interactions: supply the underlying to the extension market
        // @audit-question shouldn't we check the mTokenGateway somehow?
        // slither-disable-next-line arbitrary-send-eth
        ImTokenGateway(mTokenGateway).supplyOnHost{value: _gasFee}(amount, receiver, selector);

        // @audit-question why no event?
    }

    // ----------- PRIVATE ------------
    /// @notice Wraps a native coin into its wrapped version
    /// @param amountToWrap The amount of native coin to wrap
    function _wrap(uint256 amountToWrap) private {
        // Requirements: can wraup only up to the amount of the msg.value
        require(amountToWrap <= msg.value, WrapAndSupply_AmountNotValid());

        // Requirements: the amount to wrap must be greater than 0
        require(amountToWrap > 0, WrapAndSupply_AmountNotValid());

        // Interactions: wrap the native coin into its wrapped version
        WRAPPED_NATIVE.deposit{value: amountToWrap}();
    }
}
