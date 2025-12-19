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

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {ImToken} from "src/interfaces/ImToken.sol";
import {ExponentialNoError} from "src/utils/ExponentialNoError.sol";
import {IRewardDistributor, IRewardDistributorData} from "src/interfaces/IRewardDistributor.sol";

/// @title Reward distribution manager
/// @author Malda Protocol
/// @notice Distributes reward tokens to suppliers and borrowers across markets.
contract RewardDistributor is
    IRewardDistributor,
    ExponentialNoError,
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ----------- CONSTANTS ------------
    /// @notice Initial index used when starting accruals
    uint224 public constant REWARD_INITIAL_INDEX = 1e36;

    // ----------- STORAGE ------------
    /// @inheritdoc IRewardDistributor
    address public operator;

    /// @notice The Reward state for each reward token for each market
    mapping(address rewardToken => mapping(address mToken => IRewardDistributorData.RewardMarketState marketState))
        public rewardMarketState;

    /// @notice The Reward state for each reward token for each account
    mapping(
        address rewardToken => mapping(address account => IRewardDistributorData.RewardAccountState accountState)
    ) public rewardAccountState;

    /// @notice Added reward tokens
    address[] public rewardTokens;

    /// @inheritdoc IRewardDistributor
    mapping(address rewardToken => bool status) public isRewardToken;

    // ----------- ERRORS ------------
    /// @notice Error thrown when the caller is not the operator
    error RewardDistributor_OnlyOperator();

    /// @notice Error thrown when the transfer fails
    error RewardDistributor_TransferFailed();

    /// @notice Error thrown when the reward token is not valid
    error RewardDistributor_RewardNotValid();

    /// @notice Error thrown when the address is not valid
    error RewardDistributor_AddressNotValid();

    /// @notice Error thrown when the address is already registered
    error RewardDistributor_AddressAlreadyRegistered();

    /// @notice Error thrown when the supply speed array length mismatch
    error RewardDistributor_SupplySpeedArrayLengthMismatch();

    /// @notice Error thrown when the borrow speed array length mismatch
    error RewardDistributor_BorrowSpeedArrayLengthMismatch();

    // ----------- MODIFIERS ------------
    /// @notice Modifier to check if the caller is the operator
    modifier onlyOperator() {
        // Requirements: the caller is the operator
        require(msg.sender == operator, RewardDistributor_OnlyOperator());
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    /// @notice Disable initializers for the implementation
    constructor() {
        _disableInitializers();
    }

    // ----------- OWNER ------------
    /// @notice Sets the operator allowed to notify indices
    /// @param _operator Operator address
    function setOperator(address _operator) external onlyOwner {
        // Requirements: the operator address is not zero
        require(_operator != address(0), RewardDistributor_AddressNotValid());

        // Events: emit the operator set event
        emit OperatorSet(operator, _operator);

        // Effects: set the operator
        operator = _operator;
    }

    // ----------- OPERATOR ------------
    /// @inheritdoc IRewardDistributor
    function notifySupplyIndex(address mToken) external override onlyOperator {
        address rewardToken;
        uint256 rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            rewardToken = rewardTokens[i];

            // Effects: update the supply index
            _notifySupplyIndex(rewardToken, mToken);

            // Events: emit the supply index notified event
            emit SupplyIndexNotified(rewardToken, mToken);
        }
    }

    /// @inheritdoc IRewardDistributor
    function notifyBorrowIndex(address mToken) external override onlyOperator {
        address rewardToken;
        uint256 rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            rewardToken = rewardTokens[i];

            // Effects: update the borrow index
            _notifyBorrowIndex(rewardToken, mToken);

            // Events: emit the borrow index notified event
            emit BorrowIndexNotified(rewardToken, mToken);
        }
    }

    /// @inheritdoc IRewardDistributor
    /// @notice Accrues supplier rewards for all reward tokens on a market
    /// @param mToken Market address
    /// @param supplier Supplier address
    function notifySupplier(address mToken, address supplier) external override onlyOperator {
        uint256 rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            // Effects: update the supplier rewards
            _notifySupplier(rewardTokens[i], mToken, supplier);
        }
    }

    /// @inheritdoc IRewardDistributor
    /// @notice Accrues borrower rewards for all reward tokens on a market
    /// @param mToken Market address
    /// @param borrower Borrower address
    function notifyBorrower(address mToken, address borrower) external override onlyOperator {
        uint256 rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            // Effects: update the borrower rewards
            _notifyBorrower(rewardTokens[i], mToken, borrower);
        }
    }

    /// @notice Initializes the upgradeable contract
    /// @param _owner Owner address
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    // ----------- PUBLIC ------------
    /// @notice Grants reward to a user
    /// @param token Reward token address
    /// @param user User address
    /// @param amount Amount to grant
    function grantReward(address token, address user, uint256 amount) public onlyOwner {
        // Requirements: the reward token is valid
        require(isRewardToken[token], RewardDistributor_RewardNotValid());

        // Effects: grant the reward
        _grantReward(token, user, amount);
    }

    /// @notice Claims rewards for a list of holders across all reward tokens
    /// @param holders Account list to claim for
    function claim(address[] memory holders) public override nonReentrant {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            // Effects: claim the rewards
            _claim(rewardTokens[i], holders);
        }
    }

    /// @notice Whitelists a new reward token
    /// @param rewardToken_ Reward token address
    function whitelistToken(address rewardToken_) public onlyOwner {
        // Requirements: the reward token address is not zero
        require(rewardToken_ != address(0), RewardDistributor_AddressNotValid());

        // Requirements: the reward token is not already whitelisted
        require(!isRewardToken[rewardToken_], RewardDistributor_AddressAlreadyRegistered());

        // Effects: add the reward token to the list
        rewardTokens.push(rewardToken_);

        // Effects: set the reward token status
        isRewardToken[rewardToken_] = true;

        // Events: emit the token whitelisted event
        emit WhitelistedToken(rewardToken_);
    }

    /// @notice Updates reward speeds for multiple markets
    /// @param rewardToken_ Reward token address
    /// @param mTokens Market addresses
    /// @param supplySpeeds Supply speeds per market
    /// @param borrowSpeeds Borrow speeds per market
    function updateRewardSpeeds(
        address rewardToken_,
        address[] memory mTokens,
        uint256[] memory supplySpeeds,
        uint256[] memory borrowSpeeds
    ) public onlyOwner {
        // Requirements: the reward token is valid
        require(isRewardToken[rewardToken_], RewardDistributor_RewardNotValid());

        // Requirements: the array lengths match
        require(mTokens.length == supplySpeeds.length, RewardDistributor_SupplySpeedArrayLengthMismatch());
        require(mTokens.length == borrowSpeeds.length, RewardDistributor_BorrowSpeedArrayLengthMismatch());

        for (uint256 i = 0; i < mTokens.length; i++) {
            // Effects: update the reward speed
            _updateRewardSpeed(rewardToken_, mTokens[i], supplySpeeds[i], borrowSpeeds[i]);
        }
    }

    // ----------- VIEW ------------
    /// @inheritdoc IRewardDistributor
    function getBlockTimestamp() public view override returns (uint32) {
        // needs to have a string error message
        return safe32(block.timestamp, "block timestamp exceeds 32 bits");
    }

    /// @inheritdoc IRewardDistributor
    function getRewardTokens() public view override returns (address[] memory) {
        return rewardTokens;
    }

    // ----------- INTERNAL ------------
    /// @notice Claims rewards for holders for a given token
    /// @param rewardToken Reward token address
    /// @param holders Holder list
    function _claim(address rewardToken, address[] memory holders) internal {
        IRewardDistributorData.RewardAccountState storage accountState;
        for (uint256 j = 0; j < holders.length; j++) {
            accountState = rewardAccountState[rewardToken][holders[j]];

            // Effects: grant the rewards
            accountState.rewardAccrued = _grantReward(rewardToken, holders[j], accountState.rewardAccrued);
        }
    }

    /// @notice Transfers accrued rewards to a user
    /// @param token Reward token
    /// @param user Recipient address
    /// @param amount Amount to grant
    /// @return Remaining amount (if transfer not fully executed)
    function _grantReward(address token, address user, uint256 amount) internal returns (uint256) {
        uint256 remaining = ImToken(token).balanceOf(address(this));
        if (amount > 0 && amount <= remaining) {
            bool status = ImToken(token).transfer(user, amount);
            // Requirements: the transfer was successful
            require(status, RewardDistributor_TransferFailed());

            // Events: emit the reward granted event
            emit RewardGranted(token, user, amount);
            return 0;
        }
        return amount;
    }

    // ----------- PRIVATE ------------
    /// @notice Updates supply/borrow speed and indexes for a market
    /// @param rewardToken Reward token address
    /// @param mToken Market address
    /// @param supplySpeed New supply speed
    /// @param borrowSpeed New borrow speed
    function _updateRewardSpeed(address rewardToken, address mToken, uint256 supplySpeed, uint256 borrowSpeed) private {
        IRewardDistributorData.RewardMarketState storage marketState = rewardMarketState[rewardToken][mToken];

        if (marketState.supplySpeed != supplySpeed) {
            if (marketState.supplyIndex == 0) {
                // Effects: reset the supply index
                marketState.supplyIndex = REWARD_INITIAL_INDEX;
            }

            // Effects: update the supply index
            _notifySupplyIndex(rewardToken, mToken);

            // Events: emit the supply index notified event
            emit SupplyIndexNotified(rewardToken, mToken);

            // Effects: set the supply speed
            marketState.supplySpeed = supplySpeed;

            // Events: emit the supply speed updated event
            emit SupplySpeedUpdated(rewardToken, mToken, supplySpeed);
        }

        if (marketState.borrowSpeed != borrowSpeed) {
            if (marketState.borrowIndex == 0) {
                // Effects: reset the borrow index
                marketState.borrowIndex = REWARD_INITIAL_INDEX;
            }

            // Effects: update the borrow index
            _notifyBorrowIndex(rewardToken, mToken);

            // Events: emit the borrow index notified event
            emit BorrowIndexNotified(rewardToken, mToken);

            // Effects: set the borrow speed
            marketState.borrowSpeed = borrowSpeed;

            // Events: emit the borrow speed updated event
            emit BorrowSpeedUpdated(rewardToken, mToken, borrowSpeed);
        }
    }

    /// @notice Updates supply index for a reward token/market pair
    /// @param rewardToken Reward token address
    /// @param mToken Market address
    function _notifySupplyIndex(address rewardToken, address mToken) private {
        IRewardDistributorData.RewardMarketState storage marketState = rewardMarketState[rewardToken][mToken];

        uint32 blockTimestamp = getBlockTimestamp();

        if (blockTimestamp > marketState.supplyBlock) {
            if (marketState.supplySpeed > 0) {
                uint256 deltaBlocks = blockTimestamp - marketState.supplyBlock;
                uint256 supplyTokens = ImToken(mToken).totalSupply();
                uint256 accrued = mul_(deltaBlocks, marketState.supplySpeed);
                Double memory ratio = supplyTokens > 0 ? fraction(accrued, supplyTokens) : Double({mantissa: 0});

                // Effects: set the supply index
                marketState.supplyIndex = safe224(
                    add_(Double({mantissa: marketState.supplyIndex}), ratio).mantissa,
                    "new index exceeds 224 bits" // needs to be a string
                );
            }

            // Effects: set the supply block
            marketState.supplyBlock = blockTimestamp;
        }
    }

    /// @notice Updates borrow index for a reward token/market pair
    /// @param rewardToken Reward token address
    /// @param mToken Market address
    function _notifyBorrowIndex(address rewardToken, address mToken) private {
        Exp memory marketBorrowIndex = Exp({mantissa: ImToken(mToken).borrowIndex()});

        IRewardDistributorData.RewardMarketState storage marketState = rewardMarketState[rewardToken][mToken];

        uint32 blockTimestamp = getBlockTimestamp();

        if (blockTimestamp > marketState.borrowBlock) {
            if (marketState.borrowSpeed > 0) {
                uint256 deltaBlocks = blockTimestamp - marketState.borrowBlock;
                uint256 borrowAmount = div_(ImToken(mToken).totalBorrows(), marketBorrowIndex);
                uint256 accrued = mul_(deltaBlocks, marketState.borrowSpeed);
                Double memory ratio = borrowAmount > 0 ? fraction(accrued, borrowAmount) : Double({mantissa: 0});

                // Effects: set the borrow index
                marketState.borrowIndex = safe224(
                    add_(Double({mantissa: marketState.borrowIndex}), ratio).mantissa,
                    "new index exceeds 224 bits" // needs to be a string
                );
            }

            // Effects: set the borrow block
            marketState.borrowBlock = blockTimestamp;
        }
    }

    /// @notice Accrues supplier rewards for a market
    /// @param rewardToken Reward token address
    /// @param mToken Market address
    /// @param supplier Supplier address
    function _notifySupplier(address rewardToken, address mToken, address supplier) private {
        IRewardDistributorData.RewardMarketState storage marketState = rewardMarketState[rewardToken][mToken];
        IRewardDistributorData.RewardAccountState storage accountState = rewardAccountState[rewardToken][supplier];

        uint256 supplyIndex = marketState.supplyIndex;
        uint256 supplierIndex = accountState.supplierIndex[mToken];

        // Update supplier's index to the current index since we are distributing accrued Reward
        accountState.supplierIndex[mToken] = supplyIndex;

        if (supplierIndex == 0 && supplyIndex >= REWARD_INITIAL_INDEX) {
            // Effects: set the supplier index
            supplierIndex = REWARD_INITIAL_INDEX;
        }

        // Calculate change in the cumulative sum of the Reward per mToken accrued
        Double memory deltaIndex = Double({mantissa: sub_(supplyIndex, supplierIndex)});

        uint256 supplierTokens = ImToken(mToken).balanceOf(supplier);

        // Calculate Reward accrued: mTokenAmount * accruedPerMToken
        uint256 supplierDelta = mul_(supplierTokens, deltaIndex);

        // Effects: add the supplier delta to the reward accrued
        accountState.rewardAccrued = add_(accountState.rewardAccrued, supplierDelta);

        // Events: emit the reward accrued event
        emit RewardAccrued(rewardToken, supplier, supplierDelta, accountState.rewardAccrued);
    }

    /// @notice Accrues borrower rewards for a market
    /// @param rewardToken Reward token address
    /// @param mToken Market address
    /// @param borrower Borrower address
    function _notifyBorrower(address rewardToken, address mToken, address borrower) private {
        Exp memory marketBorrowIndex = Exp({mantissa: ImToken(mToken).borrowIndex()});

        IRewardDistributorData.RewardMarketState storage marketState = rewardMarketState[rewardToken][mToken];
        IRewardDistributorData.RewardAccountState storage accountState = rewardAccountState[rewardToken][borrower];

        // Effects: get the borrow index and borrower index
        uint256 borrowIndex = marketState.borrowIndex;
        uint256 borrowerIndex = accountState.borrowerIndex[mToken];

        // Update borrowers's index to the current index since we are distributing accrued Reward
        // Effects: set the borrower index
        accountState.borrowerIndex[mToken] = borrowIndex;

        if (borrowerIndex == 0 && borrowIndex >= REWARD_INITIAL_INDEX) {
            // Covers the case where users borrowed tokens before the market's borrow state index was set.
            // Rewards the user with Reward accrued from the start of when borrower rewards were first
            // set for the market.
            // Effects: set the borrower index
            borrowerIndex = REWARD_INITIAL_INDEX;
        }

        // Calculate change in the cumulative sum of the Reward per borrowed unit accrued
        // Effects: calculate the delta index
        Double memory deltaIndex = Double({mantissa: sub_(borrowIndex, borrowerIndex)});

        // Effects: calculate the borrower amount
        uint256 borrowerAmount = div_(ImToken(mToken).borrowBalanceStored(borrower), marketBorrowIndex);

        // Calculate Reward accrued: mTokenAmount * accruedPerBorrowedUnit
        uint256 borrowerDelta = mul_(borrowerAmount, deltaIndex);

        // Effects: add the borrower delta to the reward accrued
        accountState.rewardAccrued = add_(accountState.rewardAccrued, borrowerDelta);

        // Events: emit the reward accrued event
        emit RewardAccrued(rewardToken, borrower, borrowerDelta, accountState.rewardAccrued);
    }
}
