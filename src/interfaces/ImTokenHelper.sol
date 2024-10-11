// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface ImTokenHelper {
    // ----------- VIEW ------------
    /**
     * Mint **
     */
    //TODO: add risc0 params
    /**
     * @notice Checks if the account should be allowed to mint tokens in the given market
     * @param mToken Asset being minted
     * @param minter The address minting the tokens
     * @param mintAmount The amount of the underlying asset being minted
     * @param mintTokens The number of tokens being minted
     */
    function isMintValid(address mToken, address minter, uint256 mintAmount, uint256 mintTokens)
        external
        view
        returns (uint256);

    /**
     * Redeem **
     */
    /**
     * @notice  Checks if the account should be allowed to redeem tokens in the given market
     * @param mToken Asset being redeemed
     * @param redeemer The address redeeming the tokens
     * @param redeemAmount The amount of the underlying asset being redeemed
     * @param redeemTokens The number of tokens being redeemed
     */
    function isRedeemValid(address mToken, address redeemer, uint256 redeemAmount, uint256 redeemTokens)
        external
        view
        returns (uint256);

    /**
     * Borrow **
     */
    /**
     * @notice Checks if the account should be allowed to borrow the underlying asset of the given market
     * @param mToken The market to verify the borrow against
     * @param borrower The account which would borrow the asset
     * @param borrowAmount The amount of underlying the account would borrow
     */
    function isBorrowValid(address mToken, address borrower, uint256 borrowAmount) external view returns (uint256);

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
    function isRepayValid(address mToken, address payer, address borrower, uint256 repayAmount)
        external
        view
        returns (uint256);

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
    function isLiquidateValid(
        address mTokenBorrowed,
        address mTokenCollateral,
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external view returns (uint256);

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
    function isSeizeValid(
        address mTokenCollateral,
        address mTokenBorrowed,
        address liquidator,
        address borrower,
        uint256 seizeTokens
    ) external view returns (uint256);

    /**
     * Transfer **
     */
    /**
     * @notice Checks if the account should be allowed to transfer tokens in the given market
     * @param mToken The market to verify the transfer against
     * @param src The account which sources the tokens
     * @param dst The account which receives the tokens
     * @param transferTokens The number of mTokens to transfer
     * @return 0 if the transfer is allowed, otherwise a semi-opaque error code (See ErrorReporter.sol)
     */
    function isTransferValid(address mToken, address src, address dst, uint256 transferTokens)
        external
        view
        returns (uint256);
}
