// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface IRewardDistributorData {
    struct RewardMarketState {
        /// @notice The supply speed for each market
        uint256 supplySpeed;
        /// @notice The supply index for each market
        uint224 supplyIndex;
        /// @notice The last block number that Reward accrued for supply
        uint32 supplyBlock;
        /// @notice The borrow speed for each market
        uint256 borrowSpeed;
        /// @notice The borrow index for each market
        uint224 borrowIndex;
        /// @notice The last block number that Reward accrued for borrow
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

interface IRewardDistributor {
    event RewardAccrued(address indexed rewardToken, address indexed user, uint256 deltaAccrued, uint256 totalAccrued);

    event RewardGranted(address indexed rewardToken, address indexed user, uint256 amount);

    event SupplySpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 supplySpeed);

    event BorrowSpeedUpdated(address indexed rewardToken, address indexed mToken, uint256 borrowSpeed);

    /**
     * @notice The operator that rewards are distributed to
     */
    function operator() external view returns (address);

    /**
     * @notice Flag to check if reward token added before
     * @param _token the token to check for
     */
    function isRewardToken(address _token) external view returns (bool);

    /**
     * @notice Added reward tokens
     */
    function getRewardTokens() external view returns (address[] memory);

    /**
     * @notice Get block number
     */
    function getBlockTimestamp() external view returns (uint32);

    /**
     * @notice Notifies supply index
     */
    function notifySupplyIndex(address mToken) external;

    /**
     * @notice Notifies borrow index
     */
    function notifyBorrowIndex(address mToken) external;

    /**
     * @notice Notifies supplier
     */
    function notifySupplier(address mToken, address supplier) external;

    /**
     * @notice Notifies borrower
     */
    function notifyBorrower(address mToken, address borrower) external;

    /**
     * @notice Claim tokens for `holders
     * @param holders the accounts to claim for
     */
    function claim(address[] memory holders) external;
}
