// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

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

interface IOperator {
    // ----------- VIEW ------------
    /**
     * @notice Administrator for this contract
     */
    function admin() external view returns (address);
    /**
     * @notice Pending administrator for this contract
     */
    function pendingAdmin() external view returns (address);
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
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
    function accountAssets(address _user) external view returns (address[] memory mTokens);

    /**
     * @notice A list of all markets
     */
    function allMarkets() external view returns (address[] memory mTokens);

    /**
     * @notice Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.
     */
    function borroCaps(address _mToken) external view returns (uint256);

    /**
     * @notice Supply caps enforced by supplyAllowed for each cToken address. Defaults to zero which corresponds to unlimited supplying.
     */
    function supplyCaps(address _mToken) external view returns (uint256);

    /**
     * @notice Reward Distributor to markets supply and borrow (including protocol token)
     */
    function rewardDistributor() external view returns (address);

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
