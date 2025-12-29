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

// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

/// @title IMendiMarket
/// @author Merge Layers Inc.
/// @notice Interface for legacy Mendi market interactions
interface IMendiMarket {
    /// @notice Repays a borrow
    /// @param repayAmount Amount to repay or type(uint256).max
    /// @return repaidAmount Actual repaid amount
    function repayBorrow(uint256 repayAmount) external returns (uint256 repaidAmount);

    /// @notice Repays a borrow on behalf of borrower
    /// @param borrower Borrower address
    /// @param repayAmount Amount to repay
    /// @return repaidAmount Actual repaid amount
    function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256 repaidAmount);

    /// @notice Redeems underlying for given amount
    /// @param redeemAmount Amount to redeem
    /// @return redeemed Amount of underlying redeemed
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256 redeemed);

    /// @notice Redeems tokens
    /// @param amount Amount of tokens to redeem
    /// @return redeemed Amount redeemed
    function redeem(uint256 amount) external returns (uint256 redeemed);

    /// @notice Returns underlying balance of sender
    /// @param sender Address to query
    /// @return balance Underlying balance
    function balanceOfUnderlying(address sender) external returns (uint256 balance);

    /// @notice Returns underlying asset address
    /// @return asset Underlying token
    function underlying() external view returns (address asset);

    /// @notice Returns token balance of sender
    /// @param sender Address to query
    /// @return tokenBalance Token balance
    function balanceOf(address sender) external view returns (uint256 tokenBalance);

    /// @notice Returns stored borrow balance
    /// @param sender Address to query
    /// @return borrowBalance Borrow balance
    function borrowBalanceStored(address sender) external view returns (uint256 borrowBalance);
}

/// @title IMendiComptroller
/// @author Merge Layers Inc.
/// @notice Interface for fetching entered markets
interface IMendiComptroller {
    /// @notice Returns assets in for account
    /// @param account Account address
    /// @return assets List of markets
    function getAssetsIn(address account) external view returns (IMendiMarket[] memory assets);
}
