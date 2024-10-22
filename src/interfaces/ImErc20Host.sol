// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.27;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

interface ImErc20Host {
    /**
     * @notice Initializes the mErc20Host contract
     * @param underlying_ The address of the underlying asset
     * @param operator_ The address of the Operator
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     * @param zkVerifier_ The IRiscZeroVerifier address
     * @param zkVerifierImageRegistry_ The IZkVerifierImageRegistry address
     */
    function initialize(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address zkVerifier_,
        address zkVerifierImageRegistry_
    ) external;

    /**
     * @notice Mints tokens after external verification
     * @param journalData The journal data for minting
     * @param seal The Zk proof seal
     */
    function mintExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Borrows tokens after external verification
     * @param journalData The journal data for borrowing
     * @param seal The Zk proof seal
     */
    function borrowExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Repays tokens after external verification
     * @param journalData The journal data for repayment
     * @param seal The Zk proof seal
     */
    function repayExternal(bytes calldata journalData, bytes calldata seal) external;

    /**
     * @notice Withdraws tokens after external verification
     * @param journalData The journal data for withdrawing
     * @param seal The Zk proof seal
     */
    function withdrawExternal(bytes calldata journalData, bytes calldata seal) external;
}
