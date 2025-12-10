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

// slither-disable-start costly-loop
// interfaces
import {IRoles} from "src/interfaces/IRoles.sol";
import {ImToken, ImTokenMinimal} from "src/interfaces/ImToken.sol";
import {IInterestRateModel} from "src/interfaces/IInterestRateModel.sol";

// contracts
import {ExponentialNoError} from "src/utils/ExponentialNoError.sol";

/// @title mTokenStorage
/// @author Merge Layers Inc.
/// @notice Storage contract for mToken
abstract contract mTokenStorage is ImToken, ExponentialNoError {
    // ----------- TYPES ------------

    /// @notice Container for borrow balance information
    struct BorrowSnapshot {
        /// @notice Total balance (with accrued interest), after applying the most recent balance-changing action
        uint256 principal;
        /// @notice Global borrowIndex as of the most recent balance-changing action
        uint256 interestIndex;
    }

    /// @notice Maximum fraction of interest that can be set aside for reserves
    uint256 internal constant RESERVE_FACTOR_MAX_MANTISSA = 1e18;

    /// @notice Share of seized collateral that is added to reserves
    uint256 internal constant PROTOCOL_SEIZE_SHARE_MANTISSA = 2.8e16; //2.8%

    // ----------- ACCESS STORAGE ------------
    /// @inheritdoc ImToken
    address payable public admin;

    /// @inheritdoc ImToken
    address payable public pendingAdmin;

    /// @inheritdoc ImToken
    address public operator;

    /// @inheritdoc ImToken
    IRoles public rolesOperator;

    // ----------- TOKENS STORAGE ------------
    /// @inheritdoc ImTokenMinimal
    string public name;

    /// @inheritdoc ImTokenMinimal
    string public symbol;

    /// @inheritdoc ImTokenMinimal
    uint8 public decimals;

    // ----------- MARKET STORAGE ------------
    /// @inheritdoc ImToken
    address public interestRateModel;

    /// @inheritdoc ImToken
    uint256 public reserveFactorMantissa;

    /// @inheritdoc ImToken
    uint256 public accrualBlockTimestamp;

    /// @inheritdoc ImToken
    uint256 public borrowIndex;

    /// @inheritdoc ImToken
    uint256 public totalBorrows;

    /// @inheritdoc ImToken
    uint256 public totalReserves;

    /// @inheritdoc ImTokenMinimal
    uint256 public totalSupply;

    /// @inheritdoc ImTokenMinimal
    uint256 public totalUnderlying;

    /// @notice Maximum borrow rate that can ever be applied
    uint256 public borrowRateMaxMantissa = 0.0005e16;

    // Mapping of account addresses to outstanding borrow balances
    /// @notice Mapping of account addresses to borrow snapshots
    mapping(address account => BorrowSnapshot snapshot) internal accountBorrows;

    // Official record of token balances for each account
    /// @notice Mapping of account addresses to token balances
    mapping(address account => uint256 tokens) internal accountTokens;

    // Approved token transfer amounts on behalf of others
    /// @notice Mapping of owner to spender to allowance amount
    mapping(address owner => mapping(address spender => uint256 amount)) internal transferAllowances;

    /// @notice Initial exchange rate used when minting the first mTokens (used when totalSupply = 0)
    uint256 internal initialExchangeRateMantissa;

    // slither-disable-next-line shadowing-state
    uint256[50] private __gap;

    // ----------- ACCESS EVENTS ------------
    /// @notice Event emitted when rolesOperator is changed
    /// @param oldRoles Previous roles contract
    /// @param newRoles New roles contract
    event NewRolesOperator(address indexed oldRoles, address indexed newRoles);

    /// @notice Event emitted when Operator is changed
    /// @param oldOperator Previous operator address
    /// @param newOperator New operator address
    event NewOperator(address indexed oldOperator, address indexed newOperator);

    // ----------- TOKENS EVENTS ------------
    /// @notice EIP20 Transfer event
    /// @param from Sender address
    /// @param to Receiver address
    /// @param amount Amount transferred
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @notice EIP20 Approval event
    /// @param owner Token owner
    /// @param spender Spender address
    /// @param amount Allowed amount
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    // ----------- MARKETS EVENTS ------------
    /// @notice Event emitted when interest is accrued
    /// @param cashPrior Cash prior to accrual
    /// @param interestAccumulated Interest accumulated during accrual
    /// @param borrowIndex New borrow index
    /// @param totalBorrows Total borrows after accrual
    event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);

    /// @notice Event emitted when tokens are minted
    /// @param minter Address initiating mint
    /// @param receiver Receiver of minted tokens
    /// @param mintAmount Amount of underlying supplied
    /// @param mintTokens Amount of mTokens minted
    event Mint(address indexed minter, address indexed receiver, uint256 mintAmount, uint256 mintTokens);

    /// @notice Event emitted when tokens are redeemed
    /// @param redeemer Address redeeming tokens
    /// @param redeemAmount Amount of underlying redeemed
    /// @param redeemTokens Number of tokens redeemed
    event Redeem(address indexed redeemer, uint256 redeemAmount, uint256 redeemTokens);

    /// @notice Event emitted when underlying is borrowed
    /// @param borrower Borrower address
    /// @param borrowAmount Amount borrowed
    /// @param accountBorrows Account borrow balance
    /// @param totalBorrows Total borrows after action
    event Borrow(address indexed borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);

    /// @notice Event emitted when a borrow is repaid
    /// @param payer Address paying back
    /// @param borrower Borrower whose debt is reduced
    /// @param repayAmount Amount repaid
    /// @param accountBorrows Borrower's balance after repay
    /// @param totalBorrows Total borrows after repay
    event RepayBorrow(
        address indexed payer,
        address indexed borrower,
        uint256 repayAmount,
        uint256 accountBorrows,
        uint256 totalBorrows
    );

    /// @notice Event emitted when a borrow is liquidated
    /// @param liquidator Liquidator address
    /// @param borrower Borrower being liquidated
    /// @param repayAmount Amount repaid
    /// @param mTokenCollateral Collateral market
    /// @param seizeTokens Tokens seized
    event LiquidateBorrow(
        address indexed liquidator,
        address indexed borrower,
        uint256 repayAmount,
        address indexed mTokenCollateral,
        uint256 seizeTokens
    );

    /// @notice Event emitted when interestRateModel is changed
    /// @param oldInterestRateModel Previous interest rate model
    /// @param newInterestRateModel New interest rate model
    event NewMarketInterestRateModel(address indexed oldInterestRateModel, address indexed newInterestRateModel);

    /// @notice Event emitted when the reserve factor is changed
    /// @param oldReserveFactorMantissa Previous reserve factor
    /// @param newReserveFactorMantissa New reserve factor
    event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);

    /// @notice Event emitted when the reserves are added
    /// @param benefactor Address adding reserves
    /// @param addAmount Amount added
    /// @param newTotalReserves Total reserves after addition
    event ReservesAdded(address indexed benefactor, uint256 addAmount, uint256 newTotalReserves);

    /// @notice Event emitted when the reserves are reduced
    /// @param admin Address removing reserves
    /// @param reduceAmount Amount removed
    /// @param newTotalReserves Total reserves after reduction
    event ReservesReduced(address indexed admin, uint256 reduceAmount, uint256 newTotalReserves);

    /// @notice Event emitted when the borrow max mantissa is updated
    /// @param oldVal Previous max mantissa
    /// @param maxMantissa New max mantissa
    event NewBorrowRateMaxMantissa(uint256 oldVal, uint256 maxMantissa);

    /// @notice Event emitted when same chain flow state is enabled or disabled
    /// @param sender Address updating the state
    /// @param _oldState Previous state
    /// @param _newState New state
    event SameChainFlowStateUpdated(address indexed sender, bool _oldState, bool _newState);

    /// @notice Event emitted when zkVerifier is updated
    /// @param oldVerifier Previous verifier
    /// @param newVerifier New verifier
    event ZkVerifierUpdated(address indexed oldVerifier, address indexed newVerifier);

    // ----------- ERRORS ------------
    /// @notice Thrown when caller is not admin
    error mt_OnlyAdmin();

    /// @notice Thrown when redeem amounts are zero
    error mt_RedeemEmpty();

    /// @notice Thrown when provided input is invalid
    error mt_InvalidInput();

    /// @notice Thrown when caller lacks required role
    error mt_OnlyAdminOrRole();

    /// @notice Thrown when price fetch fails
    error mt_PriceFetchFailed();

    /// @notice Thrown when transfer is not valid
    error mt_TransferNotValid();

    /// @notice Thrown when minimum amount is not met
    error mt_MinAmountNotValid();

    /// @notice Thrown when borrow rate exceeds maximum
    error mt_BorrowRateTooHigh();

    /// @notice Thrown when contract is already initialized
    error mt_AlreadyInitialized();

    /// @notice Thrown when reserve factor exceeds limit
    error mt_ReserveFactorTooHigh();

    /// @notice Thrown when exchange rate is invalid
    error mt_ExchangeRateNotValid();

    /// @notice Thrown when market method call is invalid
    error mt_MarketMethodNotValid();

    /// @notice Thrown when liquidation seizes too much collateral
    error mt_LiquidateSeizeTooMuch();

    /// @notice Thrown when redeem cash is unavailable
    error mt_RedeemCashNotAvailable();

    /// @notice Thrown when borrow cash is unavailable
    error mt_BorrowCashNotAvailable();

    /// @notice Thrown when reserve cash is unavailable
    error mt_ReserveCashNotAvailable();

    /// @notice Thrown when redeem transfer out is not possible
    error mt_RedeemTransferOutNotPossible();

    /// @notice Thrown when same chain operations are disabled
    error mt_SameChainOperationsAreDisabled();

    /// @notice Thrown when collateral block timestamp is invalid
    error mt_CollateralBlockTimestampNotValid();

    /// @notice Thrown when configuration address is invalid
    error mTokenConfiguration_AddressNotValid();

    // ----------- VIRTUAL ------------
    /// @inheritdoc ImToken
    function accrueInterest() external virtual {
        _accrueInterest();
    }

    // ----------- NON-VIRTUAL ------------
    /// @notice Accrues interest up to the current timestamp
    function _accrueInterest() internal {
        /* Remember the initial block timestamp */
        uint256 currentBlockTimestamp = _getBlockTimestamp();
        uint256 accrualBlockTimestampPrior = accrualBlockTimestamp;

        /* Short-circuit accumulating 0 interest */
        if (accrualBlockTimestampPrior == currentBlockTimestamp) return;

        /* Read the previous values out of storage */
        uint256 cashPrior = _getCashPrior();
        uint256 borrowsPrior = totalBorrows;
        uint256 reservesPrior = totalReserves;
        uint256 borrowIndexPrior = borrowIndex;

        // Interactions: calculate the current borrow interest rate
        uint256 borrowRateMantissa =
            IInterestRateModel(interestRateModel).getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        if (borrowRateMaxMantissa > 0) {
            // Requirements: the borrow rate is not greater th the max borrow rate
            require(borrowRateMantissa <= borrowRateMaxMantissa, mt_BorrowRateTooHigh());
        }

        // Calculate the number of blocks elapsed since the last accrual
        uint256 blockDelta = currentBlockTimestamp - accrualBlockTimestampPrior;

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrowsNew = interestAccumulated + totalBorrows
         *  totalReservesNew = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndexNew = simpleInterestFactor * borrowIndex + borrowIndex
         */

        Exp memory simpleInterestFactor = mul_(Exp({mantissa: borrowRateMantissa}), blockDelta);
        uint256 interestAccumulated = mul_ScalarTruncate(simpleInterestFactor, borrowsPrior);
        uint256 totalBorrowsNew = interestAccumulated + borrowsPrior;
        uint256 totalReservesNew =
            mul_ScalarTruncateAddUInt(Exp({mantissa: reserveFactorMantissa}), interestAccumulated, reservesPrior);
        uint256 borrowIndexNew = mul_ScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        // Effects: write the previously calculated values into storage
        accrualBlockTimestamp = currentBlockTimestamp;
        borrowIndex = borrowIndexNew;
        totalBorrows = totalBorrowsNew;
        totalReserves = totalReservesNew;

        // Events: emit the accrue interest event
        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndexNew, totalBorrowsNew);
    }

    /// @notice Performs a transfer in, reverting upon failure
    /// @param from Sender address
    /// @param amount Amount to transfer in
    /// @return Amount actually transferred to the protocol
    function _doTransferIn(address from, uint256 amount) internal virtual returns (uint256);

    /// @notice Performs a transfer out to recipient
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function _doTransferOut(address payable to, uint256 amount) internal virtual;

    /// @notice Calculates the exchange rate from the underlying to the MToken
    /// @dev This function does not accrue interest before calculating the exchange rate
    ///      Can generate issues if inflated by an attacker when market is created
    ///      Solution: use 0 collateral factor initially
    /// @return calculated exchange rate scaled by 1e18
    function _exchangeRateStored() internal view virtual returns (uint256) {
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            /// If there are no tokens minted:
            ///  exchangeRate = initialExchangeRate
            return initialExchangeRateMantissa;
        } else {
            /// Otherwise:
            ///  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
            uint256 totalCash = _getCashPrior();
            uint256 cashPlusBorrowsMinusReserves = totalCash + totalBorrows - totalReserves;
            uint256 exchangeRate = (cashPlusBorrowsMinusReserves * EXP_SCALE) / _totalSupply;

            return exchangeRate;
        }
    }

    /// @notice Retrieves current block timestamp (virtual for tests)
    /// @return Current block timestamp
    function _getBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /// @notice Gets balance of this contract in terms of the underlying
    /// @dev This excludes the value of the current message, if any
    /// @return The quantity of underlying owned by this contract
    function _getCashPrior() internal view virtual returns (uint256);
}
// slither-disable-end costly-loop
