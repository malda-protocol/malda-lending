// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {mErc20Upgradable} from "src/mToken/mErc20Upgradable.sol";

contract mErc20UpgradableHarnessV2 is mErc20Upgradable {
    function initializeHarness(
        address underlying_,
        address operator_,
        address interestRateModel_,
        uint256 initialExchangeRateMantissa_,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_,
        address payable admin_
    ) external {
        _proxyInitialize(
            underlying_, operator_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_, admin_
        );
    }
}
