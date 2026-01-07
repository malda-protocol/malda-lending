// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {mErc20Upgradable} from "src/mToken/mErc20Upgradable.sol";
import {mErc20Immutable} from "src/mToken/mErc20Immutable.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";

import {mToken_Unit_Shared} from "../shared/mToken_Unit_Shared.t.sol";

contract mErc20UpgradableHarness is mErc20Upgradable {
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

contract mErc20_initialize is mToken_Unit_Shared {
    function test_RevertWhen_ImmutableAdminZero() external {
        vm.expectRevert(mErc20Immutable.mErc20Immutable_AdminNotValid.selector);
        new mErc20Immutable(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(0))
        );
    }

    function test_RevertWhen_UpgradableAdminZero() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mErc20Upgradable.mErc20Upgradable_AdminNotValid.selector);
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(0))
        );
    }

    function test_RevertWhen_InitializeUnderlyingZero() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        harness.initializeHarness(
            address(0),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );
    }

    function test_RevertWhen_InitializeOperatorZero() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        harness.initializeHarness(
            address(weth), address(0), address(interestModel), 1e18, "Market WETH", "mWeth", 18, payable(address(this))
        );
    }

    function test_RevertWhen_InitializeInterestModelZero() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mTokenStorage.mt_AddressNotValid.selector);
        harness.initializeHarness(
            address(weth), address(operator), address(0), 1e18, "Market WETH", "mWeth", 18, payable(address(this))
        );
    }

    function test_RevertWhen_InitializeNameEmpty() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mTokenStorage.mt_NameNotValid.selector);
        harness.initializeHarness(
            address(weth), address(operator), address(interestModel), 1e18, "", "mWeth", 18, payable(address(this))
        );
    }

    function test_RevertWhen_InitializeSymbolEmpty() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mTokenStorage.mt_SymbolNotValid.selector);
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "",
            18,
            payable(address(this))
        );
    }

    function test_RevertWhen_InitializeDecimalsZero() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mTokenStorage.mt_DecimalsNotValid.selector);
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            0,
            payable(address(this))
        );
    }

    function test_RevertWhen_InitializeExchangeRateZero() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();

        vm.expectRevert(mTokenStorage.mt_ExchangeRateNotValid.selector);
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            0,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );
    }

    function test_RevertWhen_InitializeTwice() external {
        mErc20UpgradableHarness harness = new mErc20UpgradableHarness();
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );

        vm.expectRevert(mTokenStorage.mt_AlreadyInitialized.selector);
        harness.initializeHarness(
            address(weth),
            address(operator),
            address(interestModel),
            1e18,
            "Market WETH",
            "mWeth",
            18,
            payable(address(this))
        );
    }
}
