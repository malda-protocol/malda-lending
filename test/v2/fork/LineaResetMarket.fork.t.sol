// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
import {mTokenStorage} from "src/mToken/mTokenStorage.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

interface IWhitelistLike {
    function setWhitelistStatus(bool status) external;
}

interface IFirewallProtected {
    function hypernativeFirewallAdmin() external view returns (address);
    function setFirewall(address _firewall) external;
}

contract LineaResetMarketTest is BaseForkTest {
    address internal constant MARKET = 0x301E5481271fD4F4f4C0291F88d7d829c64E2B2b;
    address internal constant OPERATOR = 0x4bbd2B599425026b8A504816D8A043636e2D7Ec7;
    address internal constant WEETH_LINEA_HOLDER = 0x3E944fF6573a62cb9D55e39CC954Ebbdcffb7984;

    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address internal constant MARKET_ADMIN = address(0x3E8545884FE2450A2E3973c341F8A22A645289C5);

    address internal PROXY_ADMIN;
    address internal NEW_IMPL;

    function setUp() public override {
        super.setUp();
        lineaFork = vm.createSelectFork(vm.envString("LINEA_RPC_URL"), 24_326_770);
        _selectLineaFork();

        PROXY_ADMIN = address(uint160(uint256(vm.load(MARKET, ADMIN_SLOT))));

        mErc20Host impl = new mErc20Host();
        NEW_IMPL = address(impl);
    }

    ////////////////////////////////////////////////////////////
    //                      ResetMarket                       //
    ////////////////////////////////////////////////////////////

    function test_fork_resetMarket_success_upgradeResetMarketAndViews() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host m = mErc20Host(MARKET);
        _assertViewMethodsDontRevert(m);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(MARKET_ADMIN);
        ProxyAdmin(PROXY_ADMIN).upgradeAndCall(ITransparentUpgradeableProxy(payable(MARKET)), NEW_IMPL, "");

        vm.prank(MARKET_ADMIN);
        m.resetMarket();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(m.totalSupply(), 0, "totalSupply should be 0 after resetMarket");
        assertEq(m.totalBorrows(), 0, "totalBorrows should be 0 after resetMarket");
        assertEq(m.totalReserves(), 0, "totalReserves should be 0 after resetMarket");
        assertEq(m.borrowIndex(), 1e18, "borrowIndex should be reset to 1e18");
        assertEq(m.accrualBlockTimestamp(), block.timestamp, "accrual timestamp should be reset to current block");

        uint256 ex = m.exchangeRateStored();
        assertTrue(ex > 0, "exchangeRateStored should be non-zero after resetMarket");

        _assertViewMethodsDontRevert(m);
    }

    function test_fork_resetMarket_success_upgradeResetMarketAndActions() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host m = mErc20Host(MARKET);
        _assertViewMethodsDontRevert(m);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(MARKET_ADMIN);
        ProxyAdmin(PROXY_ADMIN).upgradeAndCall(ITransparentUpgradeableProxy(payable(MARKET)), NEW_IMPL, "");

        vm.prank(MARKET_ADMIN);
        m.resetMarket();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        vm.prank(m.hypernativeFirewallAdmin());
        m.setFirewall(address(0));

        assertEq(m.totalSupply(), 0, "totalSupply should be 0 after resetMarket");
        assertEq(m.totalBorrows(), 0, "totalBorrows should be 0 after resetMarket");
        assertEq(m.totalReserves(), 0, "totalReserves should be 0 after resetMarket");
        assertEq(m.borrowIndex(), 1e18, "borrowIndex should be reset to 1e18");
        assertEq(m.accrualBlockTimestamp(), block.timestamp, "accrual timestamp should be reset to current block");

        uint256 ex = m.exchangeRateStored();
        assertTrue(ex > 0, "exchangeRateStored should be non-zero after resetMarket");

        _assertViewMethodsDontRevert(m);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(MARKET_ADMIN);
        IWhitelistLike(OPERATOR).setWhitelistStatus(false);

        // Disable Operator firewall to avoid consumer registration issues
        IFirewallProtected operator = IFirewallProtected(OPERATOR);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(operator.hypernativeFirewallAdmin());
        operator.setFirewall(address(0));

        vm.warp(block.timestamp + 121);

        address underlying = m.underlying();
        IERC20 u = IERC20(underlying);
        uint256 mintAmount = 1e17;
        _fundErc20FromHolder(underlying, WEETH_LINEA_HOLDER, address(this), mintAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        u.approve(MARKET, mintAmount);
        m.mint(mintAmount, address(this), 0);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertGt(m.balanceOf(address(this)), 0, "mint should increase user mToken balance");
        assertEq(m.totalBorrows(), 0, "totalBorrows should remain 0 after mint");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 borrowAmount = mintAmount / 10;
        m.borrow(borrowAmount);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 userBorrow = m.borrowBalanceStored(address(this));
        assertGt(userBorrow, 0, "borrow should increase user borrow balance");
        assertEq(m.totalBorrows(), userBorrow, "totalBorrows should equal the user's borrow balance");

        _assertViewMethodsDontRevert(m);
    }

    function test_fork_resetMarket_reverts_whenCallerIsNotAdmin() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        mErc20Host m = mErc20Host(MARKET);

        vm.prank(MARKET_ADMIN);
        ProxyAdmin(PROXY_ADMIN).upgradeAndCall(ITransparentUpgradeableProxy(payable(MARKET)), NEW_IMPL, "");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(mTokenStorage.mt_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        m.resetMarket();
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _assertViewMethodsDontRevert(mErc20Host m) internal view {
        m.totalSupply();
        m.totalBorrows();
        m.totalReserves();
        m.borrowIndex();
        m.accrualBlockTimestamp();

        m.getCash();
        m.exchangeRateStored();
        m.borrowRatePerBlock();
        m.supplyRatePerBlock();

        m.balanceOf(address(this));
        m.borrowBalanceStored(address(this));
        m.getAccountSnapshot(address(this));
    }
}
