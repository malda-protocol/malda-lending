// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {mErc20} from "./mErc20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract mErc20Upgradable is mErc20, Initializable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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
    function proxyInitialize(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address payable admin_
    ) public {
        // Creator of the contract is admin during initialization
        admin = payable(msg.sender);

        // mErc20 initialize does the bulk of the work
        super.initialize(
            underlying_, operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_
        );

        // Set the proper admin now that initialization is done
        admin = admin_;
    }  

}
