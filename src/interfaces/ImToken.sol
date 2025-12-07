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

/*
 _____ _____ __    ____  _____
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|
*/

import {IRoles} from "./IRoles.sol";

/// @title ImTokenOperationTypes
/// @author Merge Layers Inc.
/// @notice Operation types supported by mToken contracts
interface ImTokenOperationTypes {
    enum OperationType {
        AmountIn,
        AmountInHere,
        AmountOut,
        AmountOutHere,
        Seize,
        Transfer,
        Mint,
        Borrow,
        Repay,
        Redeem,
        Liquidate,
        Rebalancing
    }
}

/// @title ImTokenDelegator
/// @author Merge Layers Inc.
/// @notice Interface for delegate-capable tokens
interface ImTokenDelegator {
    /// @notice Non-standard token able to delegate
    /// @param delegatee Address to delegate to
    function delegate(address delegatee) external;
}

/// @title ImTokenMinimal
/// @author Merge Layers Inc.
/// @notice Minimal mToken view interface
interface ImTokenMinimal {
    /// @notice EIP-20 token name for this token
    /// @return tokenName The token name
    function name() external view returns (string memory);

    /// @notice EIP-20 token symbol for this token
    /// @return tokenSymbol The token symbol
    function symbol() external view returns (string memory);

    /// @notice EIP-20 token decimals for this token
    /// @return tokenDecimals The token decimals
    function decimals() external view returns (uint8);

    /// @notice Returns the value of tokens in existence.
    /// @return supply Total token supply
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of underlying tokens
    /// @return underlyingAmount Total underlying amount
    function totalUnderlying() external view returns (uint256);

    /// @notice Returns the value of tokens owned by `account`.
    /// @param account The account to check for
    /// @return balance Token balance of account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the underlying address
    /// @return underlyingToken The underlying token address
    function underlying() external view returns (address);
}

/// @title ImToken
/// @author Merge Layers Inc.
/// @notice Core mToken interface with state views and actions
interface ImToken is ImTokenMinimal {
    // ----------- ACTIONS ------------
    /**
     * @notice Transfers `amount` tokens to the `dst` address
     * @param dst The address of the recipient
     * @param amount The number of tokens to transfer
     * @return success Whether the transfer was successful or not
     */
    function transfer(address dst, uint256 amount) external returns (bool);

    /**
     * @notice Transfers `amount` tokens from the `src` address to the `dst` address
     * @param src The address from which tokens are transferred
     * @param dst The address to which tokens are transferred
     * @param amount The number of tokens to transfer
     * @return success Whether the transfer was successful or not
     */
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);

    /**
     * @notice Approves `spender` to spend `amount` tokens on behalf of the caller
     * @param spender The address authorized to spend tokens
     * @param amount The number of tokens to approve
     * @return success Whether the approval was successful or not
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Returns the underlying asset balance of the `owner`
     * @param owner The address to query the balance of underlying assets for
     * @return balance The balance of underlying assets owned by `owner`
     */
    function balanceOfUnderlying(address owner) external returns (uint256);

    /// @notice Returns the total amount of borrows, accounting for interest
    /// @return totalBorrowsCurrentAmount The total amount of borrows
    function totalBorrowsCurrent() external returns (uint256);

    /// @notice Returns the current borrow balance for `account`, accounting for interest
    /// @param account The address to query the borrow balance for
    /// @return borrowBalance Current borrow balance
    function borrowBalanceCurrent(address account) external returns (uint256);

    /**
     * @notice Returns the current exchange rate, with interest accrued
     * @return exchangeRate The current exchange rate
     */
    function exchangeRateCurrent() external returns (uint256 exchangeRate);

    /**
     * @notice Accrues interest on the contract's outstanding loans
     */
    function accrueInterest() external;

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Will fail unless called by another mToken during the process of liquidation.
     *  Its absolutely critical to use msg.sender as the borrowed mToken and not a parameter.
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of mTokens to seize
     */
    function seize(address liquidator, address borrower, uint256 seizeTokens) external;

    /**
     * @notice Accrues interest and reduces reserves by transferring to admin
     * @param reduceAmount Amount of reduction to reserves
     */
    function reduceReserves(uint256 reduceAmount) external;

    // ----------- VIEWS ------------
    /// @notice Roles manager
    /// @return roles Roles contract
    function rolesOperator() external view returns (IRoles);

    /// @notice Administrator for this contract
    /// @return adminAddr Admin address
    function admin() external view returns (address payable adminAddr);

    /// @notice Pending administrator for this contract
    /// @return pending Pending admin address
    function pendingAdmin() external view returns (address payable pending);

    /// @notice Contract which oversees inter-mToken operations
    /// @return operatorAddr Operator address
    function operator() external view returns (address operatorAddr);

    /// @notice Model which tells what the current interest rate should be
    /// @return interestModel Interest rate model address
    function interestRateModel() external view returns (address interestModel);

    /**
     * @notice Fraction of interest currently set aside for reserves
     * @return reserveFactor Current reserve factor mantissa
     */
    function reserveFactorMantissa() external view returns (uint256 reserveFactor);

    /**
     * @notice Block timestamp that interest was last accrued at
     * @return timestamp Last accrual block timestamp
     */
    function accrualBlockTimestamp() external view returns (uint256 timestamp);

    /**
     * @notice Accumulator of the total earned interest rate since the opening of the market
     * @return index Borrow index
     */
    function borrowIndex() external view returns (uint256 index);

    /**
     * @notice Total amount of outstanding borrows of the underlying in this market
     * @return borrows Total borrows
     */
    function totalBorrows() external view returns (uint256 borrows);

    /**
     * @notice Total amount of reserves of the underlying held in this market
     * @return reserves Total reserves
     */
    function totalReserves() external view returns (uint256 reserves);

    /**
     * @notice Returns the snapshot of account details for the given `account`
     * @param account The address to query the account snapshot for
     * @return tokenBalance Token balance
     * @return borrowBalance Borrow balance
     * @return exchangeRate Exchange rate
     */
    function getAccountSnapshot(address account)
        external
        view
        returns (uint256 tokenBalance, uint256 borrowBalance, uint256 exchangeRate);

    /**
     * @notice Returns the stored borrow balance for `account`, without accruing interest
     * @param account The address to query the stored borrow balance for
     * @return storedBalance The stored borrow balance
     */
    function borrowBalanceStored(address account) external view returns (uint256 storedBalance);

    /**
     * @notice Returns the stored exchange rate, without accruing interest
     * @return exchangeRateStoredMantissa The stored exchange rate
     */
    function exchangeRateStored() external view returns (uint256 exchangeRateStoredMantissa);

    /**
     * @notice Returns the total amount of available cash in the contract
     * @return cash The total amount of cash
     */
    function getCash() external view returns (uint256 cash);

    /**
     * @notice Returns the current allowance the `spender` has from the `owner`
     * @param owner The address of the token holder
     * @param spender The address authorized to spend the tokens
     * @return allowanceAmount The current remaining number of tokens `spender` can spend
     */
    function allowance(address owner, address spender) external view returns (uint256 allowanceAmount);

    /**
     * @notice Returns the balance of tokens held by `owner`
     * @param owner The address to query the balance for
     * @return ownerBalance The balance of tokens owned by `owner`
     */
    function balanceOf(address owner) external view returns (uint256 ownerBalance);

    /**
     * @notice Returns the current borrow rate per block
     * @return borrowRate The current borrow rate per block, scaled by 1e18
     */
    function borrowRatePerBlock() external view returns (uint256 borrowRate);

    /**
     * @notice Returns the current supply rate per block
     * @return supplyRate The current supply rate per block, scaled by 1e18
     */
    function supplyRatePerBlock() external view returns (uint256 supplyRate);
}
