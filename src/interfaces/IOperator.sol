// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IRoles} from "./IRoles.sol";

interface IOperatorData {
    struct Market {
        // Whether or not this market is listed
        bool isListed;
        //  Multiplier representing the most one can borrow against their collateral in this market.
        //  For instance, 0.9 to allow borrowing 90% of collateral value.
        //  Must be between 0 and 1, and stored as a mantissa.
        uint256 collateralFactorMantissa;
        // Per-market mapping of "accounts in this asset"
        mapping(address => bool) accountMembership;
        // Whether or not this market receives COMP
        bool isComped;
    }
}

interface IOperatorAccess {
    /**
     * @notice Administrator for this contract
     */
    function admin() external view returns (address);
    /**
     * @notice Pending administrator for this contract
     */
    function pendingAdmin() external view returns (address);
}

interface IOperator {
    // ----------- VIEW ------------
    /**
     * @notice Roles manager
     */
    function rolesOpeartor() external view returns (IRoles);

    /**
     * @notice Oracle which gives the price of any given asset
     */
    function oracleOperator() external view returns (address);

    /**
     * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
     */
    function closeFactorMantissa() external view returns (uint256);

    /**
     * @notice Multiplier representing the discount on collateral that a liquidator receives
     */
    function liquidationIncentiveMantissa() external view returns (uint256);

    /**
     * @notice Returns the assets an account has entered
     * @param _user The address of the account to pull assets for
     * @return mTokens A dynamic list with the assets the account has entered
     */
    function getAssetsIn(address _user) external view returns (address[] memory mTokens);

    /**
     * @notice A list of all markets
     */
    function getAllMarkets() external view returns (address[] memory mTokens);

    /**
     * @notice Borrow caps enforced by borrowAllowed for each mToken address. Defaults to zero which corresponds to unlimited borrowing.
     */
    function borrowCaps(address _mToken) external view returns (uint256);

    /**
     * @notice Supply caps enforced by supplyAllowed for each mToken address. Defaults to zero which corresponds to unlimited supplying.
     */
    function supplyCaps(address _mToken) external view returns (uint256);

    /**
     * @notice Reward Distributor to markets supply and borrow (including protocol token)
     */
    function rewardDistributor() external view returns (address);

    /**
     * @notice Returns whether the given account is entered in the given asset
     * @param account The address of the account to check
     * @param mToken The mToken to check
     * @return True if the account is in the asset, otherwise false.
     */
    function checkMembership(address account, address mToken) external view returns (bool);

    /**
     * @notice Determine the current account liquidity wrt collateral requirements
     * @return  account liquidity in excess of collateral requirements,
     *          account shortfall below collateral requirements)
     */
    function getAccountLiquidity(address account) external view returns (uint256, uint256);

    /**
     * @notice Determine what the account liquidity would be if the given amounts were redeemed/borrowed
     * @param mTokenModify The market to hypothetically redeem/borrow in
     * @param account The account to determine liquidity for
     * @param redeemTokens The number of tokens to hypothetically redeem
     * @param borrowAmount The amount of underlying to hypothetically borrow
     * @return hypothetical account liquidity in excess of collateral requirements,
     *         hypothetical account shortfall below collateral requirements)
     */
    function getHypotheticalAccountLiquidity(
        address account,
        address mTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256);

    /**
     * @notice Calculate number of tokens of collateral asset to seize given an underlying amount
     * @dev Used in liquidation (called in mTokenBorrowed.liquidate)
     * @param mTokenBorrowed The address of the borrowed cToken
     * @param mTokenCollateral The address of the collateral cToken
     * @param actualRepayAmount The amount of mTokenBorrowed underlying to convert into mTokenCollateral tokens
     * @return number of mTokenCollateral tokens to be seized in a liquidation
     */
    function liquidateCalculateSeizeTokens(address mTokenBorrowed, address mTokenCollateral, uint256 actualRepayAmount)
        external
        view
        returns (uint256);

    //TODO:  add market membership view method

    // ----------- ACTIONS ------------
    /**
     * @notice Add assets to be included in account liquidity calculation
     * @param _mTokens The list of addresses of the mToken markets to be enabled
     */
    function activate(address[] calldata _mTokens) external;

    /**
     * @notice Removes asset from sender's account liquidity calculation
     * @dev Sender must not have an outstanding borrow balance in the asset,
     *  or be providing necessary collateral for an outstanding borrow.
     * @param _mToken The address of the asset to be removed
     */
    function deactivate(address _mToken) external;
}
