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

// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IOperatorData, IOperator, IOperatorDefender} from "src/interfaces/IOperator.sol";

// contracts
import {ExponentialNoError} from "src/utils/ExponentialNoError.sol";

/// @title OperatorStorage
/// @author Merge Layers Inc.
/// @notice Storage contract for Operator
abstract contract OperatorStorage is IOperator, IOperatorDefender, ExponentialNoError {
    // ----------- TYPES ------------
    /// @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
    struct AccountLiquidityLocalVars {
        uint256 sumCollateral;
        uint256 sumBorrowPlusEffects;
        /// @notice Number of mTokens the account owns in the market
        uint256 mTokenBalance;
        /// @notice Amount of underlying that the account has borrowed
        uint256 borrowBalance;
        uint256 exchangeRateMantissa;
        uint256 oraclePriceMantissa;
        uint256 collateralFactorMantissa;
        uint256 liquidationIncentiveMantissa;
        uint256 borrowLimitMantissa;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }

    // ----------- CONSTANTS ------------
    /// @notice closeFactorMantissa must be strictly greater than this value
    uint256 internal constant CLOSE_FACTOR_MIN_MANTISSA = 0.05e18; // 0.05

    /// @notice closeFactorMantissa must not exceed this value
    uint256 internal constant CLOSE_FACTOR_MAX_MANTISSA = 0.9e18; // 0.9

    /// @notice No collateralFactorMantissa may exceed this value
    uint256 internal constant COLLATERAL_FACTOR_MAX_MANTISSA = 0.9e18; // 0.95

    // ----------- STORAGE ------------
    /// @inheritdoc IOperator
    IRoles public rolesOperator;

    /// @inheritdoc IOperator
    IBlacklister public blacklistOperator;

    /// @inheritdoc IOperator
    address public oracleOperator;

    /// @inheritdoc IOperator
    uint256 public closeFactorMantissa;

    /// @inheritdoc IOperator
    /// @notice Mapping of markets to liquidation incentive mantissa
    mapping(address market => uint256 incentive) public liquidationIncentiveMantissa;

    /// @notice Per-account mapping of "assets you are in", capped by maxAssets
    mapping(address account => address[] assets) public accountAssets;

    /// @notice Mapping of mTokens to market data
    /// @dev Used e.g. to determine if a market is supported
    mapping(address mToken => IOperatorData.Market market) public markets;

    /// @notice A list of all markets
    address[] public allMarkets;

    /// @inheritdoc IOperator
    /// @notice Mapping of mTokens to borrow caps
    mapping(address mToken => uint256 cap) public borrowCaps;

    /// @inheritdoc IOperator
    /// @notice Mapping of mTokens to supply caps
    mapping(address mToken => uint256 cap) public supplyCaps;

    /// @inheritdoc IOperator
    /// @notice Mapping of mTokens to minimum borrow size
    mapping(address mToken => uint256 size) public minBorrowSize;

    /// @inheritdoc IOperator
    uint256 public limitPerTimePeriod;

    /// @inheritdoc IOperator
    uint256 public cumulativeOutflowVolume;

    /// @inheritdoc IOperator
    uint256 public lastOutflowResetTimestamp;

    // Outflow time window
    /// @inheritdoc IOperator
    uint256 public outflowResetTimeWindow;

    /// @inheritdoc IOperator
    /// @notice Mapping of users to whitelist status
    mapping(address user => bool whitelisted) public userWhitelisted;

    /// @notice Whether whitelist is enabled
    bool public whitelistEnabled;

    /// @notice Mapping of mTokens to operation types to pause status
    mapping(address mToken => mapping(ImTokenOperationTypes.OperationType actionType => bool paused)) internal _paused;

    uint256[50] private __gap;

    // ----------- EVENTS ------------
    /// @notice Emitted when user whitelist status is changed
    /// @param user Address of the user
    /// @param state Whitelist state
    event UserWhitelisted(address indexed user, bool state);

    /// @notice Emitted when whitelist is enabled
    event WhitelistEnabled();

    /// @notice Emitted when whitelist is disabled
    event WhitelistDisabled();

    /// @notice Emitted when pause status is changed
    /// @param mToken Market address
    /// @param _type Operation type paused
    /// @param state New pause state
    event ActionPaused(address indexed mToken, ImTokenOperationTypes.OperationType _type, bool state);

    /// @notice Emitted when borrow cap for a mToken is changed
    /// @param mToken Market address
    /// @param newBorrowCap New borrow cap
    event NewBorrowCap(address indexed mToken, uint256 newBorrowCap);

    /// @notice Emitted when supply cap for a mToken is changed
    /// @param mToken Market address
    /// @param newBorrowCap New supply cap
    event NewSupplyCap(address indexed mToken, uint256 newBorrowCap);

    /// @notice Emitted when an admin supports a market
    /// @param mToken Market listed
    event MarketListed(address mToken);

    /// @notice Emitted when an account enters a market
    /// @param mToken Market entered
    /// @param account Account entering
    event MarketEntered(address indexed mToken, address indexed account);

    /// @notice Emitted when an account exits a market
    /// @param mToken Market exited
    /// @param account Account exiting
    event MarketExited(address indexed mToken, address indexed account);

    /// @notice Emitted when close factor is changed by admin
    /// @param oldCloseFactorMantissa Previous close factor
    /// @param newCloseFactorMantissa New close factor
    event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);

    /// @notice Emitted when a collateral factor is changed by admin
    /// @param mToken Market address
    /// @param oldCollateralFactorMantissa Previous collateral factor
    /// @param newCollateralFactorMantissa New collateral factor
    event NewCollateralFactor(
        address indexed mToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa
    );

    /// @notice Emitted when liquidation incentive is changed by admin
    /// @param market Market address
    /// @param oldLiquidationIncentiveMantissa Previous incentive
    /// @param newLiquidationIncentiveMantissa New incentive
    event NewLiquidationIncentive(
        address market, uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa
    );

    /// @notice Emitted when price oracle is changed
    /// @param oldPriceOracle Previous price oracle
    /// @param newPriceOracle New price oracle
    event NewPriceOracle(address indexed oldPriceOracle, address indexed newPriceOracle);

    /// @notice Event emitted when rolesOperator is changed
    /// @param oldRoles Previous roles operator
    /// @param newRoles New roles operator
    event NewRolesOperator(address indexed oldRoles, address indexed newRoles);

    /// @notice Event emitted when outflow limit is updated
    /// @param sender Caller updating limit
    /// @param oldLimit Previous limit
    /// @param newLimit New limit
    event OutflowLimitUpdated(address indexed sender, uint256 oldLimit, uint256 newLimit);

    /// @notice Event emitted when outflow reset time window is updated
    /// @param oldWindow Previous window
    /// @param newWindow New window
    event OutflowTimeWindowUpdated(uint256 oldWindow, uint256 newWindow);

    /// @notice Event emitted when outflow volume has been reset
    event OutflowVolumeReset();

    /// @notice Event emitted when min borrow size set for markets
    /// @param markets Markets being updated
    /// @param amounts Borrow size amounts
    event MinBorrowSizeSet(address[] markets, uint256[] amounts);

    // ----------- ERRORS ------------
    /// @notice Error when action is paused
    error Operator_Paused();

    /// @notice Error when data mismatch occurs
    error Operator_Mismatch();

    /// @notice Error when caller is not admin
    error Operator_OnlyAdmin();

    /// @notice Error when oracle price is empty
    error Operator_EmptyPrice();

    /// @notice Error when wrong market is referenced
    error Operator_WrongMarket();

    /// @notice Error when input is invalid
    error Operator_InvalidInput();

    /// @notice Error when asset is not found
    error Operator_AssetNotFound();

    /// @notice Error when repay amount exceeds allowed
    error Operator_RepayingTooMuch();

    /// @notice Error when caller lacks admin or role permissions
    error Operator_OnlyAdminOrRole();

    /// @notice Error when market is not listed
    error Operator_MarketNotListed();

    /// @notice Error when user is blacklisted
    error Operator_UserBlacklisted();

    /// @notice Error when price fetch fails
    error Operator_PriceFetchFailed();

    /// @notice Error when sender must be token
    error Operator_SenderMustBeToken();

    /// @notice Error when user is not whitelisted
    error Operator_UserNotWhitelisted();

    /// @notice Error when market supply cap reached
    error Operator_MarketSupplyReached();

    /// @notice Error when repay amount invalid
    error Operator_RepayAmountNotValid();

    /// @notice Error when market already listed
    error Operator_MarketAlreadyListed();

    /// @notice Error when outflow volume reached
    error Operator_OutflowVolumeReached();

    /// @notice Error when roles operator invalid
    error Operator_InvalidRolesOperator();

    /// @notice Error when insufficient liquidity
    error Operator_InsufficientLiquidity();

    /// @notice Error when borrow size not met
    error Operator_MarketBorrowSizeNotMet();

    /// @notice Error when borrow cap reached
    error Operator_MarketBorrowCapReached();

    /// @notice Error when collateral factor invalid
    error Operator_InvalidCollateralFactor();

    /// @notice Error when blacklist operator invalid
    error Operator_InvalidBlacklistOperator();

    /// @notice Error when oracle underlying fetch fails
    error Operator_OracleUnderlyingFetchError();

    /// @notice Error when market has balance owed during deactivation
    error Operator_Deactivate_MarketBalanceOwed();
}
