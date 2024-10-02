// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {mTokenConfiguration} from "./mTokenConfiguration.sol";

abstract contract mTokenDefenser is mTokenConfiguration {
    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param mToken The market to verify the mint against
     * @param minter The account which would get the minted tokens
     * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
     */
    function _beforeMint(address mToken, address minter, uint256 mintAmount) internal virtual;

    /**
     * @notice Defense hook for mint
     * @param mToken Asset being minted
     * @param minter The address minting the tokens
     * @param mintAmount The amount of the underlying asset being minted
     * @param mintTokens The number of tokens being minted
     */
    function _afterMint(address mToken, address minter, uint256 mintAmount, uint256 mintTokens) internal virtual;

    //TODO: add risc0 params
    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param mToken The market to verify the mint against
     * @param minter The account which would get the minted tokens
     * @param mintAmount The amount of underlying being supplied to the market in exchange for tokens
     */
    function _beforeMintExternal(address mToken, address minter, uint256 mintAmount) internal virtual;

    /**
     * Redeem **
     */
    /**
     * @notice Checks if the account should be allowed to redeem tokens in the given market
     * @param mToken The market to verify the redeem against
     * @param redeemer The account which would redeem the tokens
     * @param redeemTokens The number of mToken to exchange for the underlying asset in the market
     */
    function _beforeRedeem(address mToken, address redeemer, uint256 redeemTokens) internal virtual;

    /**
     * @notice Validates redeem and reverts on rejection. May emit logs.
     * @param mToken Asset being redeemed
     * @param redeemer The address redeeming the tokens
     * @param redeemAmount The amount of the underlying asset being redeemed
     * @param redeemTokens The number of tokens being redeemed
     */
    function _afterRedeem(address mToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens)
        internal
        virtual;

    /**
     * Borrow **
     */
    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param mToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     */
    function _beforeBorrow(address mToken, address borrower, uint256 borrowAmount) internal virtual;

    /**
     * @notice Validates borrow and reverts on rejection. May emit logs.
     * @param mToken Asset whose underlying is being borrowed
     * @param borrower The address borrowing the underlying
     * @param borrowAmount The amount of the underlying asset requested to borrow
     */
    function _afterBorrow(address mToken, address borrower, uint256 borrowAmount) internal virtual;

    //TODO: add risc0 params
    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param mToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     */
    function _beforeBorrowExternal(address mToken, address borrower, uint256 borrowAmount) internal virtual;
    /**
     * Repay **
     */
    /**
     * @notice Checks if the account should be allowed to repay a borrow in the given market
     * @param mToken The market to verify the repay against
     * @param payer The account which would repay the asset
     * @param borrower The account which would borrowed the asset
     * @param repayAmount The amount of the underlying asset the account would repay
     */
    function _beforeRepay(address mToken, address payer, address borrower, uint256 repayAmount) internal virtual;

    /**
     * @notice Validates repayBorrow and reverts on rejection. May emit logs.
     * @param mToken Asset being repaid
     * @param payer The address repaying the borrow
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function _afterRepay(
        address mToken,
        address payer,
        address borrower,
        uint256 actualRepayAmount,
        uint256 borrowerIndex
    ) internal virtual;

    /**
     * Liquidate **
     */
    /**
     * @notice Checks if the liquidation should be allowed to occur
     * @param mTokenBorrowed Asset which was borrowed by the borrower
     * @param mTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param repayAmount The amount of underlying being repaid
     */
    function _beforeLiquidate(
        address mTokenBorrowed,
        address mTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) internal virtual;

    /**
     * @notice Validates liquidateBorrow and reverts on rejection. May emit logs.
     * @param mTokenBorrowed Asset which was borrowed by the borrower
     * @param mTokenCollateral Asset which was used as collateral and will be seized
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param actualRepayAmount The amount of underlying being repaid
     */
    function _afterLiquidate(
        address mTokenBorrowed,
        address mTokenCollateral,
        address liquidator,
        address borrower,
        uint256 actualRepayAmount,
        uint256 seizeTokens
    ) internal virtual;

    /**
     * Seize **
     */
    /**
     * @notice Checks if the seizing of assets should be allowed to occur
     * @param mTokenCollateral Asset which was used as collateral and will be seized
     * @param mTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function _beforeSeize(
        address mTokenCollateral,
        address mTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) internal virtual;

    /**
     * @notice Validates seize and reverts on rejection. May emit logs.
     * @param mTokenCollateral Asset which was used as collateral and will be seized
     * @param mTokenBorrowed Asset which was borrowed by the borrower
     * @param liquidator The address repaying the borrow and seizing the collateral
     * @param borrower The address of the borrower
     * @param seizeTokens The number of collateral tokens to seize
     */
    function _afterSeize(
        address mTokenCollateral,
        address mTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) internal virtual;

    /**
     * Transfer **
     */
    //TODO: we probably don't need this if we inherit ERC20

    /**
     * @notice Checks if the account should be allowed to transfer tokens in the given market
     * @param mToken The market to verify the transfer against
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of mTokens to transfer
     */
    function _beforeTransfer(address mToken, address src, address dst, uint256 transferTokens) internal virtual;

    /**
     * @notice Validates transfer and reverts on rejection. May emit logs.
     * @param mToken Asset being transferred
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of mTokens to transfer
     */
    function _afterTransfer(address mToken, address src, address dst, uint256 transferTokens) internal virtual;
}
