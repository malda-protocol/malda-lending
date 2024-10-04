// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IOperatorAccess, IOperatorData, IOperator} from "../interfaces/IOperator.sol";
import {IOracleOperator} from "../interfaces/IOracleOperator.sol";
import {ImToken} from "../interfaces/ImToken.sol";
import {IRoles} from "../interfaces/IRoles.sol";

import {ExponentialNoError} from "../math/ExponentialNoError.sol";

contract Operator is IOperatorAccess, IOperator, ExponentialNoError {
    // ----------- STORAGE ------------
    // closeFactorMantissa must be strictly greater than this value
    uint256 internal constant CLOSE_FACTOR_MIN_MANTISSA = 0.05e18; // 0.05

    // closeFactorMantissa must not exceed this value
    uint256 internal constant CLOSE_FACTOR_MAX_MANTISSA = 0.9e18; // 0.9

    // No collateralFactorMantissa may exceed this value
    uint256 internal constant COLLATERAL_FACTOR_MAX_MANTISSA = 0.9e18; // 0.9

    /**
     * @inheritdoc IOperatorAccess
     */
    address public override admin;

    /**
     * @inheritdoc IOperatorAccess
     */
    address public override pendingAdmin;

    /**
     * @inheritdoc IOperator
     */
    IRoles public override rolesOpeartor;

    /**
     * @inheritdoc IOperator
     */
    address public override oracleOperator;

    /**
     * @inheritdoc IOperator
     */
    uint256 public override closeFactorMantissa;

    /**
     * @inheritdoc IOperator
     */
    uint256 public override liquidationIncentiveMantissa;

    /**
     * @notice Per-account mapping of "assets you are in", capped by maxAssets
     */
    mapping(address => address[]) public accountAssets;

    /**
     * @notice Official mapping of mTokens -> Market metadata
     * @dev Used e.g. to determine if a market is supported
     */
    mapping(address => IOperatorData.Market) public markets;

    /**
     * @notice A list of all markets
     */
    address[] public allMarkets;

    /**
     * @inheritdoc IOperator
     */
    mapping(address => uint256) public override borrowCaps;

    /**
     * @inheritdoc IOperator
     */
    mapping(address => uint256) public override supplyCaps;

    /**
     * @inheritdoc IOperator
     */
    address public override rewardDistributor;

    /**
     * @dev Local vars for avoiding stack-depth limits in calculating account liquidity.
     *  Note that `mTokenBalance` is the number of mTokens the account owns in the market,
     *  whereas `borrowBalance` is the amount of underlying that the account has borrowed.
     */
    struct AccountLiquidityLocalVars {
        uint256 sumCollateral;
        uint256 sumBorrowPlusEffects;
        uint256 mTokenBalance;
        uint256 borrowBalance;
        uint256 exchangeRateMantissa;
        uint256 oraclePriceMantissa;
        Exp collateralFactor;
        Exp exchangeRate;
        Exp oraclePrice;
        Exp tokensToDenom;
    }

    // ----------- ERRORS ------------

    error Operator_MarketNotListed();
    error Operator_MarketAlreadyListed();
    error Operator_Deactivate_SnapshotFetchingFailed();
    error Operator_Deactivate_MarketBalanceOwed();
    error Operator_OracleUnderlyingFetchError();
    error Operator_InsufficientLiquidity();
    error Operator_AssetNotFound();
    error Operator_PriceFetchFailed();
    error Operator_OnlyAdmin();
    error Operator_OnlyAdminOrRole();
    error Operator_InvalidCollateralFactor();
    error Operator_EmptyPrice();
    error Operator_WrongMarket();

    // ----------- EVENTS ------------
    /**
     * @notice Emitted when an account enters a market
     */
    event MarketEntered(address indexed mToken, address indexed account);
    /**
     * @notice Emitted when an account exits a market
     */
    event MarketExited(address indexed mToken, address indexed account);
    /**
     * @notice Emitted Emitted when close factor is changed by admin
     */
    event NewCloseFactor(uint256 oldCloseFactorMantissa, uint256 newCloseFactorMantissa);
    /**
     * @notice Emitted when a collateral factor is changed by admin
     */
    event NewCollateralFactor(
        address indexed mToken, uint256 oldCollateralFactorMantissa, uint256 newCollateralFactorMantissa
    );

    /**
     * @notice Emitted when liquidation incentive is changed by admin
     */
    event NewLiquidationIncentive(uint256 oldLiquidationIncentiveMantissa, uint256 newLiquidationIncentiveMantissa);

    /**
     * @notice Emitted when price oracle is changed
     */
    event NewPriceOracle(address indexed oldPriceOracle, address indexed newPriceOracle);

    // ----------- MODIFIERS ------------
    modifier onlyAdmin() {
        require(msg.sender == admin, Operator_OnlyAdmin());
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    // ----------- OWNER ------------
    /**
     * @notice Sets a new price oracle
     * @dev Admin function to set a new price oracle
     */
    function setPriceOracle(address newOracle) external onlyAdmin {
        emit NewPriceOracle(oracleOperator, newOracle);
        oracleOperator = newOracle;
    }

    /**
     * @notice Sets the closeFactor used when liquidating borrows
     * @dev Admin function to set closeFactor
     * @param newCloseFactorMantissa New close factor, scaled by 1e18
     */
    function setCloseFactor(uint256 newCloseFactorMantissa) external onlyAdmin {
        emit NewCloseFactor(closeFactorMantissa, newCloseFactorMantissa);
        closeFactorMantissa = newCloseFactorMantissa;
    }

    
    // ----------- VIEW ------------
    /**
     * @inheritdoc IOperator
     */

    function getAssetsIn(address _user) external view override returns (address[] memory mTokens) {
        return accountAssets[_user];
    }

    /**
     * @inheritdoc IOperator
     */
    function checkMembership(address account, address mToken) external view returns (bool) {
        return markets[mToken].accountMembership[account];
    }

    /**
     * @inheritdoc IOperator
     */
    function getAllMarkets() external view returns (address[] memory mTokens) {
        return allMarkets;
    }

    /**
     * @inheritdoc IOperator
     */
    function getAccountLiquidity(address account) public view returns (uint256, uint256) {
        (, uint256 tokensHeld, uint256 amountOwed, uint256 excRateMantissa) =
            ImToken(address(0)).getAccountSnapshot(msg.sender);

        return _getHypotheticalAccountLiquidity(account, address(0), 0, 0, tokensHeld, amountOwed, excRateMantissa);
    }

    /**
     * @inheritdoc IOperator
     */
    function getHypotheticalAccountLiquidity(
        address account,
        address mTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount
    ) external view returns (uint256, uint256) {
        (, uint256 tokensHeld, uint256 amountOwed, uint256 excRateMantissa) =
            ImToken(address(0)).getAccountSnapshot(msg.sender);

        return _getHypotheticalAccountLiquidity(
            account, mTokenModify, redeemTokens, borrowAmount, tokensHeld, amountOwed, excRateMantissa
        );
    }

    /**
     * @inheritdoc IOperator
     */
    function liquidateCalculateSeizeTokens(address mTokenBorrowed, address mTokenCollateral, uint256 actualRepayAmount)
        external
        view
        returns (uint256)
    {
        /* Read oracle prices for borrowed and collateral markets */
        uint256 priceBorrowedMantissa = IOracleOperator(oracleOperator).getUnderlyingPrice(mTokenBorrowed);
        uint256 priceCollateralMantissa = IOracleOperator(oracleOperator).getUnderlyingPrice(mTokenCollateral);
        require(priceBorrowedMantissa > 0 || priceCollateralMantissa > 0, Operator_PriceFetchFailed());

        /*
         * Get the exchange rate and calculate the number of collateral tokens to seize:
         *  seizeAmount = actualRepayAmount * liquidationIncentive * priceBorrowed / priceCollateral
         *  seizeTokens = seizeAmount / exchangeRate
         *   = actualRepayAmount * (liquidationIncentive * priceBorrowed) / (priceCollateral * exchangeRate)
         */
        uint256 exchangeRateMantissa = ImToken(mTokenCollateral).exchangeRateStored();

        Exp memory numerator;
        Exp memory denominator;
        Exp memory ratio;
        numerator = mul_(Exp({mantissa: liquidationIncentiveMantissa}), Exp({mantissa: priceBorrowedMantissa}));
        denominator = mul_(Exp({mantissa: priceCollateralMantissa}), Exp({mantissa: exchangeRateMantissa}));
        ratio = div_(numerator, denominator);

        return mul_ScalarTruncate(ratio, actualRepayAmount);
    }

    // ----------- PUBLIC ------------
    /**
     * @inheritdoc IOperator
     */
    function activate(address[] calldata _mTokens) external override {
        uint256 len = _mTokens.length;
        for (uint256 i = 0; i < len; i++) {
            address __mToken = _mTokens[i];
            _activateMarket(__mToken, msg.sender);
        }
    }

    /**
     * @inheritdoc IOperator
     */
    function deactivate(address _mToken) external override {
        IOperatorData.Market storage marketToExit = markets[_mToken];
        /* Return  if the sender is not already ‘in’ the market */
        if (!marketToExit.accountMembership[msg.sender]) return;

        /* Get sender tokensHeld and amountOwed underlying from the mToken */
        (uint256 oErr, uint256 tokensHeld, uint256 amountOwed, uint256 excRateMantissa) =
            ImToken(_mToken).getAccountSnapshot(msg.sender);
        //todo: revert directly in mToken
        require(oErr == 0, Operator_Deactivate_SnapshotFetchingFailed());
        require(amountOwed == 0, Operator_Deactivate_MarketBalanceOwed());

        /* Redeem check */
        _redeemCheck(_mToken, msg.sender, tokensHeld, amountOwed, excRateMantissa);

        /* Set mToken account membership to false */
        delete marketToExit.accountMembership[msg.sender];

        /* Delete mToken from the account’s list of assets */
        // load into memory for faster iteration
        address[] memory userAssetList = accountAssets[msg.sender];
        uint256 len = userAssetList.length;
        uint256 assetIndex = len;
        for (uint256 i; i < len; i++) {
            if (userAssetList[i] == _mToken) {
                assetIndex = i;
                break;
            }
        }

        // We *must* have found the asset in the list or our redundant data structure is broken
        require(assetIndex < len, Operator_AssetNotFound());

        // copy last item in list to location of item to be removed, reduce length by 1
        address[] storage storedList = accountAssets[msg.sender];
        storedList[assetIndex] = storedList[storedList.length - 1];
        storedList.pop();

        emit MarketExited(_mToken, msg.sender);
    }

    // ----------- PRIVATE ------------
    function _activateMarket(address _mToken, address borrower) private {
        IOperatorData.Market storage marketToJoin = markets[_mToken];
        require(marketToJoin.isListed, Operator_MarketNotListed());

        if (!marketToJoin.accountMembership[borrower]) {
            marketToJoin.accountMembership[borrower] = true;
            accountAssets[borrower].push(_mToken);
            emit MarketEntered(_mToken, borrower);
        }
    }

    // todo: might have to move to a common place between Operator and mToken
    function _redeemCheck(
        address mToken,
        address redeemer,
        uint256 redeemTokens,
        uint256 amountOwed,
        uint256 exchangeRateMantissa
    ) private view {
        require(markets[mToken].isListed, Operator_MarketNotListed());

        /* If the redeemer is not 'in' the market, then we can bypass the liquidity check */
        if (!markets[mToken].accountMembership[redeemer]) return;

        // liquidity check
        (, uint256 shortfall) = _getHypotheticalAccountLiquidity(
            redeemer, mToken, redeemTokens, 0, redeemTokens, amountOwed, exchangeRateMantissa
        );
        require(shortfall == 0, Operator_InsufficientLiquidity());
    }

    function _getHypotheticalAccountLiquidity(
        address account,
        address mTokenModify,
        uint256 redeemTokens,
        uint256 borrowAmount,
        uint256 tokensHeld,
        uint256 amountOwed,
        uint256 exchangeRateMantissa
    ) private view returns (uint256, uint256) {
        AccountLiquidityLocalVars memory vars; // Holds all our calculation results
        vars.mTokenBalance = tokensHeld;
        vars.borrowBalance = amountOwed;
        vars.exchangeRateMantissa = exchangeRateMantissa;

        uint256 len = accountAssets[account].length;
        for (uint256 i; i < len; i++) {
            address _asset = accountAssets[account][i];

            vars.collateralFactor = Exp({mantissa: markets[_asset].collateralFactorMantissa});
            vars.exchangeRate = Exp({mantissa: vars.exchangeRateMantissa});

            // Get the normalized price of the asset
            vars.oraclePriceMantissa = IOracleOperator(oracleOperator).getUnderlyingPrice(_asset);
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

        return (
            vars.sumCollateral > vars.sumBorrowPlusEffects
                ? vars.sumCollateral - vars.sumBorrowPlusEffects
                : vars.sumBorrowPlusEffects - vars.sumCollateral,
            0
        );
    }
}
