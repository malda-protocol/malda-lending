// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {mErc20Host} from "src/mToken/host/mErc20Host.sol";
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

        vm.deal(MARKET_ADMIN, 100 ether);
    }

    ////////////////////////////////////////////////////////////
    //                      ResetMarket                       //
    ////////////////////////////////////////////////////////////

    function test_fork_resetMarket_success_upgradeResetMarketAndViews() external {
        mErc20Host m = mErc20Host(MARKET);

        _assertViewMethodsDontRevert(m);

        vm.startPrank(MARKET_ADMIN);
        ProxyAdmin(PROXY_ADMIN).upgradeAndCall(ITransparentUpgradeableProxy(payable(MARKET)), NEW_IMPL, "");
        m.resetMarket();
        vm.stopPrank();

        assertEq(m.totalSupply(), 0, "totalSupply changed");
        assertEq(m.totalBorrows(), 0, "totalBorrows not reset");
        assertEq(m.totalReserves(), 0, "totalReserves not reset");

        assertTrue(m.borrowIndex() > 0, "borrowIndex is zero");
        assertTrue(m.accrualBlockTimestamp() > 0, "accrualBlockTimestamp is zero");

        uint256 ex = m.exchangeRateStored();
        assertTrue(ex > 0, "exchangeRateStored is zero");

        _assertViewMethodsDontRevert(m);
    }

    function test_fork_resetMarket_success_upgradeResetMarketAndActions() external {
        mErc20Host m = mErc20Host(MARKET);

        _assertViewMethodsDontRevert(m);

        vm.startPrank(MARKET_ADMIN);
        ProxyAdmin(PROXY_ADMIN).upgradeAndCall(ITransparentUpgradeableProxy(payable(MARKET)), NEW_IMPL, "");
        m.resetMarket();
        vm.stopPrank();

        vm.prank(m.hypernativeFirewallAdmin());
        m.setFirewall(address(0));

        assertEq(m.totalSupply(), 0, "totalSupply changed");
        assertEq(m.totalBorrows(), 0, "totalBorrows not reset");
        assertEq(m.totalReserves(), 0, "totalReserves not reset");

        assertTrue(m.borrowIndex() > 0, "borrowIndex is zero");
        assertTrue(m.accrualBlockTimestamp() > 0, "accrualBlockTimestamp is zero");

        uint256 ex = m.exchangeRateStored();
        assertTrue(ex > 0, "exchangeRateStored is zero");

        _assertViewMethodsDontRevert(m);

        vm.startPrank(MARKET_ADMIN);
        IWhitelistLike(OPERATOR).setWhitelistStatus(false);
        vm.stopPrank();

        // Disable Operator firewall to avoid consumer registration issues
        IFirewallProtected operator = IFirewallProtected(OPERATOR);
        vm.prank(operator.hypernativeFirewallAdmin());
        operator.setFirewall(address(0));

        vm.warp(block.timestamp + 121);

        address underlying = m.underlying();
        IERC20 u = IERC20(underlying);
        uint256 mintAmount = 1e17;
        deal(underlying, address(this), mintAmount);

        u.approve(MARKET, mintAmount);
        m.mint(mintAmount, address(this), 0);

        assertGt(m.balanceOf(address(this)), 0, "mint failed");
        assertEq(m.totalBorrows(), 0, "borrows changed after mint");

        uint256 borrowAmount = mintAmount / 10;
        m.borrow(borrowAmount);

        uint256 userBorrow = m.borrowBalanceStored(address(this));
        assertGt(userBorrow, 0, "borrow failed");
        assertEq(m.totalBorrows(), userBorrow);

        _assertViewMethodsDontRevert(m);
    }

    // ---------- helpers ----------
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
