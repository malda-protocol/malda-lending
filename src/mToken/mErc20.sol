// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

// interfaces
import {ImErc20} from "src/interfaces/ImErc20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ImTokenMinimal, ImTokenDelegator} from "src/interfaces/ImToken.sol";

// contracts
import {mToken} from "./mToken.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Melda's mErc20 Contract
 * @notice mTokens which wrap an EIP-20 underlying
 */
contract mErc20 is mToken, ImErc20 {
    using SafeERC20 for IERC20;

    // ----------- STORAGE ------------
    /**
     * @notice Underlying asset for this mToken
     */
    address public underlying;

    // ----------- ERRORS ------------
    error mErc20_TokenNotValid();

    /**
     * @notice Initialize the new money market
     * @param underlying_ The address of the underlying asset
     * @param operator_ The address of the Operator
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     */
    function initialize(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public {
        // mToken initialize does the bulk of the work
        super.initialize(operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_);

        // Set underlying and sanity check it
        underlying = underlying_;
        ImTokenMinimal(underlying).totalSupply();
    }

    // ----------- OWNER ------------
    /**
     * @notice Admin call to delegate the votes of the MALDA-like underlying
     * @param delegatee The address to delegate votes to
     * @dev mTokens whose underlying are not  should revert here
     */
    function delegateMeldaLikeTo(address delegatee) external onlyAdmin {
        ImTokenDelegator(underlying).delegate(delegatee);
    }

    /**
     * @notice A public function to sweep accidental ERC-20 transfers to this contract. Tokens are sent to admin (timelock)
     * @param token The address of the ERC-20 token to sweep
     */
    function sweepToken(IERC20 token) external onlyAdmin {
        require(address(token) != underlying, mErc20_TokenNotValid());
        uint256 balance = token.balanceOf(address(this));
        token.safeTransfer(admin, balance);
    }

    // ----------- MARKET PUBLIC ------------
    /**
     * @inheritdoc ImErc20
     */
    function mint(uint256 mintAmount) external {
        _mint(msg.sender, mintAmount, true);
    }

    /**
     * @inheritdoc ImErc20
     */
    function redeem(uint256 redeemTokens) external {
        _redeem(msg.sender, redeemTokens, true);
    }

    /**
     * @inheritdoc ImErc20
     */
    function redeemUnderlying(uint256 redeemAmount) external {
        _redeemUnderlying(msg.sender, redeemAmount);
    }

    /**
     * @inheritdoc ImErc20
     */
    function borrow(uint256 borrowAmount) external {
        _borrow(msg.sender, borrowAmount, true);
    }

    /**
     * @inheritdoc ImErc20
     */
    function repay(uint256 repayAmount) external {
        _repay(repayAmount, true);
    }

    /**
     * @inheritdoc ImErc20
     */
    function repayBehalf(address borrower, uint256 repayAmount) external {
        _repayBehalf(borrower, repayAmount, true);
    }

    /**
     * @inheritdoc ImErc20
     */
    function liquidate(address borrower, uint256 repayAmount, address mTokenCollateral) external {
        _liquidate(borrower, repayAmount, mTokenCollateral);
    }

    /**
     * @inheritdoc ImErc20
     */
    function addReserves(uint256 addAmount) external {
        return _addReserves(addAmount);
    }

    // ----------- TOKEN PUBLIC ------------
    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying tokens owned by this contract
     */
    function _getCashPrior() internal view virtual override returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     *  This may revert due to insufficient balance or insufficient allowance.
     */
    function _doTransferIn(address from, uint256 amount) internal virtual override returns (uint256) {
        uint256 balanceBefore = IERC20(underlying).balanceOf(address(this));
        IERC20(underlying).safeTransferFrom(from, address(this), amount);
        uint256 balanceAfter = IERC20(underlying).balanceOf(address(this));
        return balanceAfter - balanceBefore;
    }

    /**
     * @dev Performs a transfer out, ideally returning an explanatory error code upon failure rather than reverting.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     */
    function _doTransferOut(address payable to, uint256 amount) internal virtual override {
        IERC20(underlying).safeTransfer(to, amount);
    }
}
