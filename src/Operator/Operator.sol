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
import {IOracleOperator} from "src/interfaces/IOracleOperator.sol";
import {ImToken, ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IOperatorData, IOperator, IOperatorDefender} from "src/interfaces/IOperator.sol";

// contracts
import {OperatorStorage} from "./OperatorStorage.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";

/// @title Operator core controller
/// @author Merge Layers Inc.
/// @notice Access-controlled operator logic for mTokens
contract Operator is OperatorStorage, ImTokenOperationTypes, OwnableUpgradeable, HypernativeFirewallProtected {
    // ----------- MODIFIERS ------------
    /// @notice Modifier to restrict access to allowed users only
    /// @param user The user address to check
    modifier onlyAllowedUser(address user) {
        if (whitelistEnabled) {
            require(userWhitelisted[user], Operator_UserNotWhitelisted());
        }
        _;
    }

    /// @notice Modifier to check if user is not blacklisted
    /// @param user The user address to check
    modifier ifNotBlacklisted(address user) {
        require(!blacklistOperator.isBlacklisted(user), Operator_UserBlacklisted());
        _;
    }

    /// @notice Disables initializers for implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ----------- OWNER ------------
    /// @notice Initializes the firewall
    /// @param _firewall The firewall address
    function initFirewall(address _firewall) external onlyOwner {
        _initHypernativeFirewall(_firewall, owner());
    }

    /// @notice Sets the blacklist operator
    /// @param _blacklister The blacklist operator address
    function setBlacklister(address _blacklister) external onlyOwner {
        // @audit-question address zero check?

        // Effects: set the blacklist operator
        blacklistOperator = IBlacklister(_blacklister);

        // @audit-question emit an event?
    }

    /// @notice Sets min borrow size per market
    /// @param mTokens The market address
    /// @param amounts The new size
    function setBorrowSizeMin(address[] calldata mTokens, uint256[] calldata amounts) external onlyOwner {
        uint256 length = mTokens.length;
        // Requirements: the lengths of the mTokens and amounts arrays are equal
        require(amounts.length == length, Operator_InvalidInput());

        for (uint256 i; i < length; ++i) {
            // Effects: set the min borrow size for the market
            minBorrowSize[mTokens[i]] = amounts[i];
        }

        // Events: emit the min borrow size set event
        emit MinBorrowSizeSet(mTokens, amounts);
    }

    /// @notice Sets user whitelist status
    /// @param user The user address
    /// @param state The new state
    function setWhitelistedUser(address user, bool state) external onlyOwner {
        // Effects: set the user whitelist status
        userWhitelisted[user] = state;

        // Events: emit the user whitisted event
        emit UserWhitelisted(user, state);
    }

    /// @notice Sets the whitelist status
    /// @param status The new status
    function setWhitelistStatus(bool status) external onlyOwner {
        // Effects: set the whitelist status
        whitelistEnabled = status;

        // Events: emit the proper whitelist event
        if (status) emit WhitelistEnabled();
        else emit WhitelistDisabled();
    }

    /// @notice Sets a new Operator for the market
    /// @param _roles The new operator address
    function setRolesOperator(address _roles) external onlyOwner {
        // Requirements: the roles is not zero address
        require(_roles != address(0), Operator_InvalidInput());

        // Effects: set the roles operator
        rolesOperator = IRoles(_roles);

        // Events: emit the new roles operator event
        emit NewRolesOperator(address(rolesOperator), _roles);
    }

    /// @notice Sets a new price oracle
    /// @dev Admin function to set a new price oracle
    /// @param newOracle Address of the new oracle
    function setPriceOracle(address newOracle) external onlyOwner {
        // Requirements: the new oracle is not zero address
        require(newOracle != address(0), Operator_InvalidInput());

        // Effects: set the price oracle
        oracleOperator = newOracle;

        // Events: emit the new price oracle event
        emit NewPriceOracle(oracleOperator, newOracle);
    }

    /// @notice Sets the closeFactor used when liquidating borrows
    /// @dev Admin function to set closeFactor
    /// @param newCloseFactorMantissa New close factor, scaled by 1e18
    function setCloseFactor(uint256 newCloseFactorMantissa) external onlyOwner {
        // Requirements: the new close factor is not less than the min close factor and not greater than the max close factor
        require(
            newCloseFactorMantissa >= CLOSE_FACTOR_MIN_MANTISSA && newCloseFactorMantissa <= CLOSE_FACTOR_MAX_MANTISSA,
            Operator_InvalidInput()
        );

        // Effects: set the close factor
        closeFactorMantissa = newCloseFactorMantissa;

        // Events: emit the new close factor event
        emit NewCloseFactor(closeFactorMantissa, newCloseFactorMantissa);
    }

    /// @notice Sets the collateralFactor for a market
    /// @dev Admin function to set per-market collateralFactor
    /// @param mToken The market to set the factor on
    /// @param newCollateralFactorMantissa The new collateral factor, scaled by 1e18
    function setCollateralFactor(address mToken, uint256 newCollateralFactorMantissa) external onlyOwner {
        IOperatorData.Market storage market = markets[address(mToken)];
        // Requirements: the market is listed
        require(market.isListed, Operator_MarketNotListed());

        Exp memory highLimit = Exp({mantissa: COLLATERAL_FACTOR_MAX_MANTISSA});
        Exp memory newCollateralFactorExp = Exp({mantissa: newCollateralFactorMantissa});
        // Requirements: the new collateral factor is not greater than the max collateral factor (0.9)
        require(!lessThanExp(highLimit, newCollateralFactorExp), Operator_InvalidCollateralFactor());

        // Requirements: the new collateral factor is not zero and the price is not zero
        require(
            newCollateralFactorMantissa == 0 || IOracleOperator(oracleOperator).getUnderlyingPrice(mToken) != 0,
            Operator_EmptyPrice()
        );

        // Effects: set the market's collateral factor to the new collateral factor
        market.collateralFactorMantissa = newCollateralFactorMantissa;

        // Events: emit the new collateral factor event
        emit NewCollateralFactor(mToken, market.collateralFactorMantissa, newCollateralFactorMantissa);
    }

    /// @notice Sets liquidationIncentive
    /// @dev Admin function to set liquidationIncentive
    /// @param market Market address
    /// @param newLiquidationIncentiveMantissa New liquidationIncentive scaled by 1e18
    function setLiquidationIncentive(address market, uint256 newLiquidationIncentiveMantissa) external onlyOwner {
        // Emit event with old incentive, new incentive
        emit NewLiquidationIncentive(market, liquidationIncentiveMantissa[market], newLiquidationIncentiveMantissa);

        // Set liquidation incentive to new incentive
        liquidationIncentiveMantissa[market] = newLiquidationIncentiveMantissa;
    }

    /// @notice Add the market to the markets mapping and set it as listed
    /// @dev Admin function to set isListed and add support for the market
    /// @param mToken The address of the market (token) to list
    function supportMarket(address mToken) external onlyOwner {
        // Requirements: the market is not already listed
        require(!markets[address(mToken)].isListed, Operator_MarketAlreadyListed());

        IOperatorData.Market storage newMarket = markets[mToken];
        // Effects: set the market as listed
        newMarket.isListed = true;
        // Effects: set the market's collateral factor to 0
        newMarket.collateralFactorMantissa = 0;

        // Requirements: the market is not already in the allMarkets array
        uint256 marketsLength = allMarkets.length;
        for (uint256 i = 0; i < marketsLength; i++) {
            require(allMarkets[i] != mToken, Operator_MarketAlreadyListed());
        }

        // Effects: add the market to the allMarkets array
        allMarkets.push(mToken);

        // Events: emit the market listed event
        emit MarketListed(mToken);
    }

    /// @notice Sets outflow volume time window
    /// @param newTimeWindow The new reset time window
    function setOutflowVolumeTimeWindow(uint256 newTimeWindow) external onlyOwner {
        // @audit-question zero check?

        // Events: emit the outflow time window updated event
        emit OutflowTimeWindowUpdated(outflowResetTimeWindow, newTimeWindow);

        // Effects: set the outflow volume time window
        outflowResetTimeWindow = newTimeWindow;
    }

    /// @notice Sets outflow volume limit
    /// @dev when 0, it means there's no limit
    /// @param amount The new limit
    function setOutflowTimeLimitInUSD(uint256 amount) external onlyOwner {
        // @audit-question zero check?

        // Events: emit the outflow limit updated event
        emit OutflowLimitUpdated(msg.sender, limitPerTimePeriod, amount);

        // Effects: set the outflow volume limit
        limitPerTimePeriod = amount;
    }

    /// @notice Resets outflow volume
    function resetOutflowVolume() external onlyOwner {
        // Effects: reset the outflow volume
        cumulativeOutflowVolume = 0;

        // Effects: reset the last outflow reset timestamp
        lastOutflowResetTimestamp = block.timestamp;

        // Events: emit the outflow volume reset event
        emit OutflowVolumeReset();
    }

    /// @notice Verifies outflow volume limit
    /// @param amount The amount to check
    function checkOutflowVolumeLimit(uint256 amount) external {
        // Requirements: the sender is a listed market
        require(markets[msg.sender].isListed, Operator_MarketNotListed());

        // Skip this check in case limit is disabled ( = 0)
        if (limitPerTimePeriod > 0) {
            // Check if we need to reset it
            if (block.timestamp > lastOutflowResetTimestamp + outflowResetTimeWindow) {
                // Effects: reset the cumulative outflow volume
                cumulativeOutflowVolume = 0;
                // Effects: reset the last outflow reset timestamp
                lastOutflowResetTimestamp = block.timestamp;
            }

            // Interactions: convert received amount to USD
            uint256 amountInUSD = _convertMarketAmountToUSDValue(amount, msg.sender);

            // Requirements: the new cumulative limits are not reached
            require(cumulativeOutflowVolume + amountInUSD <= limitPerTimePeriod, Operator_OutflowVolumeReached());

            // Effects: add the amount to the cumulative outflow volume
            cumulativeOutflowVolume += amountInUSD;
        }
    }

    /// @notice Set borrow caps for given mToken markets.
    /// @dev Borrowing that brings total borrows to or above borrow cap will revert.
    ///      A value of 0 corresponds to unlimited borrowing.
    /// @param mTokens The addresses of the markets (tokens) to change the borrow caps for
    /// @param newBorrowCaps The new borrow cap values in underlying to be set.
    function setMarketBorrowCaps(address[] calldata mTokens, uint256[] calldata newBorrowCaps)
        external
        onlyFirewallApproved
    {
        // Requirements: the sender is admin or has guardian borrow cap role
        require(
            msg.sender == owner() || rolesOperator.isAllowedFor(msg.sender, rolesOperator.GUARDIAN_BORROW_CAP()),
            Operator_OnlyAdminOrRole()
        );

        uint256 numMarkets = mTokens.length;
        uint256 numBorrowCaps = newBorrowCaps.length;
        // Requirements: check if lengths are not zero and equal
        require(numMarkets != 0 && numMarkets == numBorrowCaps, Operator_InvalidInput());

        for (uint256 i; i < numMarkets; i++) {
            // Effects: set the borrow cap for the market
            borrowCaps[mTokens[i]] = newBorrowCaps[i];

            // Events: emit the new borrow cap event
            emit NewBorrowCap(mTokens[i], newBorrowCaps[i]);
        }
    }

    /// @notice Set supply caps for the given mToken markets.
    /// @dev Supplying that brings total supply to or above supply cap will revert.
    ///      A value of 0 corresponds to unlimited supplying.
    /// @param mTokens The addresses of the markets (tokens) to change the supply caps for
    /// @param newSupplyCaps The new supply cap values in underlying to be set.
    function setMarketSupplyCaps(address[] calldata mTokens, uint256[] calldata newSupplyCaps)
        external
        onlyFirewallApproved
    {
        // Requirements: the sender is admin or has guardian supply cap role
        require(
            msg.sender == owner() || rolesOperator.isAllowedFor(msg.sender, rolesOperator.GUARDIAN_SUPPLY_CAP()),
            Operator_OnlyAdminOrRole()
        );

        uint256 numMarkets = mTokens.length;
        uint256 numSupplyCaps = newSupplyCaps.length;
        // Requirements: check if lengths are not zero and equal
        require(numMarkets != 0 && numMarkets == numSupplyCaps, Operator_InvalidInput());

        for (uint256 i; i < numMarkets; i++) {
            // Effects: set the supply cap for the market
            supplyCaps[mTokens[i]] = newSupplyCaps[i];

            // Events: emit the new supply cap event
            emit NewSupplyCap(mTokens[i], newSupplyCaps[i]);
        }
    }

    /// @inheritdoc IOperator
    function setPaused(address mToken, ImTokenOperationTypes.OperationType _type, bool state)
        external
        onlyFirewallApproved
    {
        if (state) {
            // Requirements: if pausing, the caller is admin or has guardian pause role
            require(
                msg.sender == owner() || rolesOperator.isAllowedFor(msg.sender, rolesOperator.GUARDIAN_PAUSE()),
                Operator_OnlyAdminOrRole()
            );
        } else {
            // Requirements: if unpausing, the caller is the owner
            require(msg.sender == owner(), Operator_OnlyAdmin());
        }

        // Effects: set the paused state for the market and operation type
        _paused[mToken][_type] = state;

        // Events: emit the action paused event
        emit ActionPaused(mToken, _type, state);
    }

    /// @notice Initialize the contract
    /// @param _rolesOperator The roles operator address
    /// @param _blacklistOperator The blacklist operator address
    /// @param _admin The admin address
    function initialize(address _rolesOperator, address _blacklistOperator, address _admin) external initializer {
        // Requirements: the roles operator is not zero address
        require(_rolesOperator != address(0), Operator_InvalidRolesOperator());
        // Requirements: the blacklist operator is not zero address
        require(_blacklistOperator != address(0), Operator_InvalidBlacklistOperator());
        // Requirements: the admin is not zero address
        require(_admin != address(0), Operator_InvalidInput());

        // Effects: initialize the owner
        __Ownable_init(_admin);

        // Effects: set the roles operator
        rolesOperator = IRoles(_rolesOperator);

        // Effects: set the blacklist operator
        blacklistOperator = IBlacklister(_blacklistOperator);

        // Effects: set the outflow reset time window
        outflowResetTimeWindow = 1 hours;

        // Effects: set the last outflow reset timestamp
        lastOutflowResetTimestamp = block.timestamp;

        // Effects: set the outflow limit per time period
        limitPerTimePeriod = 0;
    }

    /// @inheritdoc IOperator
    function enterMarkets(address[] calldata _mTokens)
        external
        override
        onlyAllowedUser(msg.sender)
        onlyFirewallApproved
    {
        uint256 len = _mTokens.length;
        for (uint256 i = 0; i < len; i++) {
            // Interactions: activate the market
            _activateMarket(_mTokens[i], msg.sender);
        }
    }

    /// @inheritdoc IOperator
    function enterMarketsWithSender(address _account) external override onlyAllowedUser(_account) {
        IOperatorData.Market storage market = markets[msg.sender];
        // Requirements: the sender market is listed
        require(market.isListed, Operator_MarketNotListed());

        // Interactions: activate the market
        _activateMarket(msg.sender, _account);
    }

    /// @inheritdoc IOperator
    function exitMarket(address _mToken) external override onlyFirewallApproved {
        IOperatorData.Market storage marketToExit = markets[_mToken];
        // Return  if the sender is not already 'in' the market
        if (!marketToExit.accountMembership[msg.sender]) return;

        // Interactions: get sender tokensHeld and amountOwed underlying from the mToken
        (uint256 tokensHeld, uint256 amountOwed,) = ImToken(_mToken).getAccountSnapshot(msg.sender);

        // Requirements: the sender has no outstanding borrow balance
        require(amountOwed == 0, Operator_Deactivate_MarketBalanceOwed());

        // Requirements: redeem checks
        _beforeRedeem(_mToken, msg.sender, tokensHeld);

        // Effects: set the mToken account membership to false
        delete marketToExit.accountMembership[msg.sender];

        // Effects: delete mToken from the account's list of assets
        address[] memory userAssetList = accountAssets[msg.sender]; // load into memory for faster iteration
        uint256 len = userAssetList.length;
        uint256 assetIndex = len;
        for (uint256 i; i < len; i++) {
            if (userAssetList[i] == _mToken) {
                assetIndex = i;
                break;
            }
        }

        // Requirements: the asset is found in the list
        require(assetIndex < len, Operator_AssetNotFound());

        // Effects: copy last item in list to location of item to be removed, reduce length by 1
        address[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.pop();

        // Events: emit the market exited event
        emit MarketExited(_mToken, msg.sender);
    }

    /// @inheritdoc IOperatorDefender
    function beforeMTokenTransfer(address mToken, address src, address dst, uint256 transferTokens)
        external
        override
        ifNotBlacklisted(src)
        ifNotBlacklisted(dst)
        onlyFirewallApproved
    {
        // Requirements: the transfer is not paused
        require(!_paused[mToken][OperationType.Transfer], Operator_Paused());

        // Interactions: accrue interest
        ImToken(mToken).accrueInterest();

        // Requirements: the before redeem checks pass
        _beforeRedeem(mToken, src, transferTokens);
    }

    /// @inheritdoc IOperatorDefender
    function beforeMTokenBorrow(address mToken, address borrower, uint256 borrowAmount)
        external
        override
        onlyAllowedUser(borrower)
        ifNotBlacklisted(borrower)
        onlyFirewallApproved
    {
        // Requirements: the borrow is not paused
        require(!_paused[mToken][OperationType.Borrow], Operator_Paused());
        // Requirements: the market is listed
        require(markets[mToken].isListed, Operator_MarketNotListed());

        // If market is not activated, activate it
        if (!markets[mToken].accountMembership[borrower]) {
            // Requirements: the sender is the market
            require(msg.sender == mToken, Operator_SenderMustBeToken());

            // Interactions: activate the market
            _activateMarket(mToken, borrower);

            // Requirements: the market is activated
            require(markets[mToken].accountMembership[borrower], Operator_WrongMarket());
        }

        // Requirements: the oracle price is not zero
        require(IOracleOperator(oracleOperator).getUnderlyingPrice(mToken) != 0, Operator_EmptyPrice());

        uint256 borrowCap = borrowCaps[mToken];
        // Requirements: if borrow cap is not zero, the next total borrows is less than the borrow cap
        if (borrowCap != 0) {
            uint256 totalBorrows = ImToken(mToken).totalBorrows();
            uint256 nextTotalBorrows = add_(totalBorrows, borrowAmount);
            require(nextTotalBorrows < borrowCap, Operator_MarketBorrowCapReached());
        }

        // Requirements: the borrow size is met
        uint256 totalAccountBorrowCrt = ImToken(mToken).borrowBalanceStored(borrower);
        uint256 nextTotalAccountBorrow = add_(totalAccountBorrowCrt, borrowAmount);
        require(nextTotalAccountBorrow > minBorrowSize[mToken], Operator_MarketBorrowSizeNotMet());

        // Requirements: the liquidity check passes
        (, uint256 shortfall) = _getHypotheticalAccountLiquidity(borrower, mToken, 0, borrowAmount);
        require(shortfall == 0, Operator_InsufficientLiquidity());
    }

    // ----------- VIEW ------------
    /// @inheritdoc IOperator
    function isPaused(address mToken, ImTokenOperationTypes.OperationType _type) external view override returns (bool) {
        return _paused[mToken][_type];
    }

    /// @inheritdoc IOperator
    function getAssetsIn(address _user) external view override returns (address[] memory mTokens) {
        return accountAssets[_user];
    }

    /// @inheritdoc IOperator
    function checkMembership(address account, address mToken) external view returns (bool) {
        return markets[mToken].accountMembership[account];
    }

    /// @inheritdoc IOperator
    function getAllMarkets() external view returns (address[] memory mTokens) {
        return allMarkets;
    }

    /// @inheritdoc IOperator
    function isDeprecated(address mToken) external view override returns (bool) {
        return _isDeprecated(mToken);
    }

    /// @inheritdoc IOperator
    function isMarketListed(address mToken) external view override returns (bool) {
        return markets[mToken].isListed;
    }

    /// @inheritdoc IOperator
    function getHypotheticalAccountLiquidity(
        address account,
        address mTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256) {
        return _getHypotheticalAccountLiquidity(account, mTokenModify, redeemTokens, borrowAmount);
    }

    /// @inheritdoc IOperatorDefender
    function beforeMTokenMint(address mToken, address minter, address receiver)
        external
        view
        override
        onlyAllowedUser(minter)
        ifNotBlacklisted(minter)
        ifNotBlacklisted(receiver)
        onlyFirewallApproved
        onlyAllowedUser(minter)
    {
        // Requirements: the mint is not paused
        require(!_paused[mToken][OperationType.Mint], Operator_Paused());

        // Requirements: the market is listed
        require(markets[mToken].isListed, Operator_MarketNotListed());
    }

    /// @inheritdoc IOperatorDefender
    function afterMTokenMint(address mToken) external view override {
        uint256 supplyCap = supplyCaps[mToken];
        // Supply cap of 0 corresponds to unlimited borrowing
        if (supplyCap != 0) {
            uint256 totalSupply = ImToken(mToken).totalSupply();
            Exp memory exchangeRate = Exp({mantissa: ImToken(mToken).exchangeRateStored()});
            uint256 totalAmount = mul_ScalarTruncate(exchangeRate, totalSupply);

            // Requirements: the total amount is less than the supply cap
            require(totalAmount <= supplyCap, Operator_MarketSupplyReached());
        }
    }

    /// @inheritdoc IOperatorDefender
    function beforeMTokenRedeem(address mToken, address redeemer, uint256 redeemTokens)
        external
        view
        override
        onlyAllowedUser(redeemer)
        ifNotBlacklisted(redeemer)
        onlyFirewallApproved
    {
        _beforeRedeem(mToken, redeemer, redeemTokens);
    }

    /// @inheritdoc IOperatorDefender
    function beforeMTokenRepay(address mToken, address borrower)
        external
        view
        onlyAllowedUser(borrower)
        onlyFirewallApproved
    {
        // Requirements: the repay is not paused
        require(!_paused[mToken][OperationType.Repay], Operator_Paused());

        // Requirements: the market is listed
        require(markets[mToken].isListed, Operator_MarketNotListed());
    }

    /// @inheritdoc IOperatorDefender
    function beforeMTokenLiquidate(
        address mTokenBorrowed,
        address mTokenCollateral,
        address borrower,
        uint256 repayAmount
    ) external view override onlyFirewallApproved {
        // Requirements: the liquidate is not paused
        require(!_paused[mTokenBorrowed][OperationType.Liquidate], Operator_Paused());

        // Requirements: the borrowed market is listed
        require(markets[mTokenBorrowed].isListed, Operator_MarketNotListed());

        // Requirements: the collateral market is listed
        require(markets[mTokenCollateral].isListed, Operator_MarketNotListed());

        uint256 borrowBalance = ImToken(mTokenBorrowed).borrowBalanceStored(borrower);
        if (_isDeprecated(mTokenBorrowed)) {
            // Requirements: the repay amount is valid
            require(borrowBalance == repayAmount, Operator_RepayAmountNotValid());
        } else {
            (, uint256 shortfall) = _getHypotheticalAccountLiquidity(borrower, address(0), 0, 0);
            // Requirements: the shortfall is greater than zero
            require(shortfall > 0, Operator_InsufficientLiquidity());

            // Requirements: the liquidator may not repay more than what is allowed by the closeFactor
            uint256 maxClose = mul_ScalarTruncate(Exp({mantissa: closeFactorMantissa}), borrowBalance);
            require(repayAmount <= maxClose, Operator_RepayingTooMuch());
        }
    }

    /// @inheritdoc IOperatorDefender
    function beforeMTokenSeize(address mTokenCollateral, address mTokenBorrowed, address liquidator)
        external
        view
        override
        ifNotBlacklisted(liquidator)
        onlyFirewallApproved
    {
        // Requirements: the seize is not paused
        require(
            !_paused[mTokenCollateral][OperationType.Seize] && !_paused[mTokenBorrowed][OperationType.Seize],
            Operator_Paused()
        );
        // Requirements: the borrowed market is listed
        require(markets[mTokenBorrowed].isListed, Operator_MarketNotListed());

        // Requirements: the collateral market is listed
        require(markets[mTokenCollateral].isListed, Operator_MarketNotListed());

        // Requirements: the collateral and borrowed markets have the same operator
        require(ImToken(mTokenCollateral).operator() == ImToken(mTokenBorrowed).operator(), Operator_Mismatch());
    }

    /// @notice Returns USD value for all markets
    /// @return sum The total USD value of all markets
    function getUSDValueForAllMarkets() external view returns (uint256 sum) {
        uint256 marketsLength = allMarkets.length;
        ImToken _market;
        for (uint256 i = 0; i < marketsLength; i++) {
            _market = ImToken(allMarkets[i]);

            // If the market is deprecated, skip it
            if (_isDeprecated(address(_market))) continue;

            // Interactions: convert the market volume to USD value
            uint256 totalMarketVolume = _market.totalUnderlying();
            sum += _convertMarketAmountToUSDValue(totalMarketVolume, address(_market));
        }
    }

    /// @inheritdoc IOperatorDefender
    function beforeRebalancing(address mToken) external view override onlyFirewallApproved {
        // Requirements: the rebalancing is not paused
        require(!_paused[mToken][OperationType.Rebalancing], Operator_Paused());
    }

    /// @notice Registers an account with the firewall
    /// @param _account Account to register
    function firewallRegister(address _account) public override(HypernativeFirewallProtected) {
        super.firewallRegister(_account);
    }

    // ----------- PRIVATE ------------
    /// @notice Converts a market amount to USD value
    /// @param amount The amount to convert
    /// @param mToken The market to convert
    /// @return usdValue The USD value of the amount
    function _convertMarketAmountToUSDValue(uint256 amount, address mToken) internal view returns (uint256 usdValue) {
        uint256 oraclePriceMantissa = IOracleOperator(oracleOperator).getUnderlyingPrice(mToken);
        // Requirements: the oracle price is not zero
        require(oraclePriceMantissa != 0, Operator_OracleUnderlyingFetchError());

        Exp memory oraclePrice = Exp({mantissa: oraclePriceMantissa});
        usdValue = mul_(amount, oraclePrice) / 1e10;
    }

    /// @notice Activates a market for a borrower
    /// @param _mToken The market to activate
    /// @param borrower The borrower to activate the market for
    function _activateMarket(address _mToken, address borrower) private {
        IOperatorData.Market storage marketToJoin = markets[_mToken];
        // Requirements: the market is listed
        require(marketToJoin.isListed, Operator_MarketNotListed());

        // If market is not activated, activate it
        if (!marketToJoin.accountMembership[borrower]) {
            // Effects: set the market account membership to true
            marketToJoin.accountMembership[borrower] = true;

            // Effects: add the market to the account's list of assets
            accountAssets[borrower].push(_mToken);

            // Events: emit the market entered event
            emit MarketEntered(_mToken, borrower);
        }
    }

    /// @notice Checks if the redeemer is in the market and has sufficient liquidity
    /// @param mToken The market to check
    /// @param redeemer The redeemer to check
    /// @param redeemTokens The number of tokens to redeem
    function _beforeRedeem(address mToken, address redeemer, uint256 redeemTokens) private view {
        // Requirements: the redeem is not paused
        require(!_paused[mToken][OperationType.Redeem], Operator_Paused());

        // Requirements: the market is listed
        require(markets[mToken].isListed, Operator_MarketNotListed());

        // If the redeemer is not 'in' the market, then we can bypass the liquidity check
        if (!markets[mToken].accountMembership[redeemer]) return;

        // Requirements: the liquidity check passes
        (, uint256 shortfall) = _getHypotheticalAccountLiquidity(redeemer, mToken, redeemTokens, 0);
        require(shortfall == 0, Operator_InsufficientLiquidity());
    }

    /// @notice Gets the hypothetical account liquidity
    /// @param account The account to get the liquidity for
    /// @param mTokenModify The market to modify
    /// @param redeemTokens The number of tokens to redeem
    /// @param borrowAmount The amount of underlying to borrow
    /// @return liquidity The liquidity in excess of collateral requirements
    /// @return shortfall The shortfall below collateral requirements
    function _getHypotheticalAccountLiquidity(
        address account,
        address mTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) private view returns (uint256, uint256) {
        AccountLiquidityLocalVars memory vars; // Holds all our calculation results

        uint256 len = accountAssets[account].length;
        for (uint256 i; i < len; i++) {
            address _asset = accountAssets[account][i];
            // Interactions: read the balances and exchange rate from the mToken
            (vars.mTokenBalance, vars.borrowBalance, vars.exchangeRateMantissa) =
                ImToken(_asset).getAccountSnapshot(account);

            vars.collateralFactor = Exp({mantissa: markets[_asset].collateralFactorMantissa});
            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});

            // Interactions: get the normalized price of the asset
            vars.oraclePriceMantissa = IOracleOperator(oracleOperator).getUnderlyingPrice(_asset);
            // Requirements: the oracle price is not zero
            require(vars.oraclePriceMantissa != 0, Operator_OracleUnderlyingFetchError());

            vars.oraclePrice = Exp({mantissa: vars.oraclePriceMantissa});

            // Pre-compute a conversion factor from tokens -> ether (normalized price value)
            vars.tokensToDenom = mul_(mul_(vars.collateralFactor, vars.exchangeRate), vars.oraclePrice);

            // sumCollateral += tokensToDenom * mTokenBalance
            vars.sumCollateral = mul_ScalarTruncateAddUInt(vars.tokensToDenom, vars.mTokenBalance, vars.sumCollateral);

            // sumBorrowPlusEffects += oraclePrice * borrowBalance
            vars.sumBorrowPlusEffects =
                mul_ScalarTruncateAddUInt(vars.oraclePrice, vars.borrowBalance, vars.sumBorrowPlusEffects);

            // Calculate effects of interacting with mTokenModify
            if (_asset == mTokenModify) {
                // redeem effect
                // sumBorrowPlusEffects += tokensToDenom * redeemTokens
                vars.sumBorrowPlusEffects =
                    mul_ScalarTruncateAddUInt(vars.tokensToDenom, redeemTokens, vars.sumBorrowPlusEffects);

                // borrow effect
                // sumBorrowPlusEffects += oraclePrice * borrowAmount
                vars.sumBorrowPlusEffects =
                    mul_ScalarTruncateAddUInt(vars.oraclePrice, borrowAmount, vars.sumBorrowPlusEffects);
            }
        }

        if (vars.sumCollateral > vars.sumBorrowPlusEffects) {
            return (vars.sumCollateral - vars.sumBorrowPlusEffects, 0);
        } else {
            return (0, vars.sumBorrowPlusEffects - vars.sumCollateral);
        }
    }

    /// @notice Checks if a market is deprecated
    /// @param mToken The market address
    /// @return deprecated True if the market is deprecated
    function _isDeprecated(address mToken) private view returns (bool) {
        return markets[mToken].collateralFactorMantissa == 0 && _paused[mToken][OperationType.Borrow]
            && ImToken(mToken).reserveFactorMantissa() == 1e18;
    }
}
