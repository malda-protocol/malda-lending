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

/// @title IRewardDistributorData
/// @author Merge Layers Inc.
/// @notice Storage structs for reward distributor
interface IRewardDistributorData {
    struct RewardMarketState {
        /// @notice The supply speed for each market
        uint256 supplySpeed;
        /// @notice The supply index for each market
        uint224 supplyIndex;
        /// @notice The last block timestamp that Reward accrued for supply
        uint32 supplyBlock;
        /// @notice The borrow speed for each market
        uint256 borrowSpeed;
        /// @notice The borrow index for each market
        uint224 borrowIndex;
        /// @notice The last block timestamp that Reward accrued for borrow
        uint32 borrowBlock;
    }

    struct RewardAccountState {
        /// @notice The supply index for each market as of the last time the account accrued Reward
        mapping(address => uint256) supplierIndex;
        /// @notice The borrow index for each market as of the last time the account accrued Reward
        mapping(address => uint256) borrowerIndex;
        /// @notice Accrued Reward but not yet transferred
        uint256 rewardAccrued;
    }
}

/// @title IRewardDistributor
/// @author Merge Layers Inc.
/// @notice Interface for reward distribution operations
interface IRewardDistributor {
    /// @notice Emitted when reward is accrued for a user
    /// @param rewardToken Reward token address
    /// @param user User address
    /// @param deltaAccrued Newly accrued amount
    /// @param totalAccrued Total accrued amount
    event RewardAccrued(address indexed rewardToken, address indexed user, uint256 deltaAccrued, uint256 totalAccrued);

    /// @notice Emitted when reward is granted to a user
    /// @param rewardToken Reward token address
    /// @param user User address
    /// @param amount Granted amount
    event RewardGranted(address indexed rewardToken, address indexed user, uint256 amount);

    /// @notice Emitted when supply speed is updated
    /// @param rewardToken Reward token address
    /// @param mToken Market token
    /// @param supplySpeed New supply speed
    event SupplySpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 supplySpeed);

    /// @notice Emitted when borrow speed is updated
    /// @param rewardToken Reward token address
    /// @param mToken Market token
    /// @param borrowSpeed New borrow speed
    event BorrowSpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 borrowSpeed);

    /// @notice Emitted when operator is updated
    /// @param oldOperator Previous operator
    /// @param newOperator New operator
    event OperatorSet(address indexed oldOperator, address indexed newOperator);

    /// @notice Emitted when token is whitelisted
    /// @param token Whitelisted token
    event WhitelistedToken(address indexed token);

    /// @notice Emitted when supply index is notified
    /// @param rewardToken Reward token address
    /// @param mToken Market token
    event SupplyIndexNotified(address indexed rewardToken, address indexed mToken);

    /// @notice Emitted when borrow index is notified
    /// @param rewardToken Reward token address
    /// @param mToken Market token
    event BorrowIndexNotified(address indexed rewardToken, address indexed mToken);

    // ----------- ACTIONS -----------
    /// @notice Notifies supply index
    /// @param mToken Market token
    function notifySupplyIndex(address mToken) external;

    /// @notice Notifies borrow index
    /// @param mToken Market token
    function notifyBorrowIndex(address mToken) external;

    /// @notice Notifies supplier
    /// @param mToken Market token
    /// @param supplier Supplier address
    function notifySupplier(address mToken, address supplier) external;

    /// @notice Notifies borrower
    /// @param mToken Market token
    /// @param borrower Borrower address
    function notifyBorrower(address mToken, address borrower) external;

    /// @notice Claim tokens for holders
    /// @param holders The accounts to claim for
    function claim(address[] memory holders) external;

    // ----------- VIEWS -----------
    /// @notice The operator that rewards are distributed to
    /// @return operatorAddress Operator address
    function operator() external view returns (address operatorAddress);

    /// @notice Flag to check if reward token added before
    /// @param _token The token to check for
    /// @return isRewardTokenAdded True if token is a reward token
    function isRewardToken(address _token) external view returns (bool isRewardTokenAdded);

    /// @notice Added reward tokens
    /// @return rewardTokens Array of reward token addresses
    function getRewardTokens() external view returns (address[] memory rewardTokens);

    /// @notice Get block timestamp
    /// @return timestamp Current block timestamp
    function getBlockTimestamp() external view returns (uint32 timestamp);
}
