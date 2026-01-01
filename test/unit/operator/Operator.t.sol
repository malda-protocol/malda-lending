// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Base_Unit_Test} from "test/Base_Unit_Test.t.sol";
import {Operator} from "src/Operator/Operator.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";
import {Roles} from "src/Roles.sol";
import {Blacklister} from "src/blacklister/Blacklister.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";

import {MockMToken} from "test/mocks/MockMToken.sol";
import {MockFirewall} from "test/mocks/MockFirewall.sol";

contract OperatorHarness is Operator {
    function callOnlyAllowedUser(address user) external onlyAllowedUser(user) {}

    function callIfNotBlacklisted(address user) external ifNotBlacklisted(user) {}

    function pushAllMarkets(address mToken) external {
        allMarkets.push(mToken);
    }

    function setMarketListed(address mToken, bool listed) external {
        markets[mToken].isListed = listed;
    }

    function setAccountMembership(address mToken, address account, bool status) external {
        markets[mToken].accountMembership[account] = status;
    }

    function setAccountAssets(address account, address[] calldata assets) external {
        delete accountAssets[account];
        for (uint256 i; i < assets.length; ++i) {
            accountAssets[account].push(assets[i]);
        }
    }
}

contract OperatorTest is Base_Unit_Test {
    uint256 private constant CLOSE_FACTOR_MIN = 0.05e18;
    uint256 private constant CLOSE_FACTOR_MAX = 0.9e18;
    uint256 private constant COLLATERAL_FACTOR_MAX = 0.9e18;

    MockMToken internal market;
    MockMToken internal market2;
    address internal guardian = address(0xBEEF);

    function setUp() public override {
        super.setUp();
        market = new MockMToken();
        market2 = new MockMToken();
        market.setOperator(address(operator));
        market2.setOperator(address(operator));
        vm.label(address(market), "MockMarket");
        vm.label(address(market2), "MockMarket2");
        vm.label(guardian, "Guardian");
    }

    function _listMarket(MockMToken mToken) internal {
        operator.supportMarket(address(mToken));
    }

    function _deployHarness() internal returns (OperatorHarness) {
        OperatorHarness harnessImpl = new OperatorHarness();
        bytes memory initData =
            abi.encodeWithSelector(Operator.initialize.selector, address(roles), address(blacklister), address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(address(harnessImpl), initData);
        return OperatorHarness(address(proxy));
    }

    function _enableFirewall() internal returns (MockFirewall) {
        MockFirewall firewall = new MockFirewall();
        operator.initFirewall(address(firewall));
        return firewall;
    }

    function testWhitelistBlocksNonWhitelisted() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.enterMarkets(markets);

        operator.setWhitelistedUser(alice, true);
        vm.prank(alice);
        operator.enterMarkets(markets);
        assertTrue(operator.checkMembership(alice, address(market)));
    }

    function testWhitelistAllowsWhitelistedUserForListedMarket() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(alice, true);

        vm.prank(address(market));
        operator.enterMarketsWithSender(alice);

        assertTrue(operator.checkMembership(alice, address(market)));
    }

    function testOnlyAllowedUserUsesWhitelist() public {
        OperatorHarness harness = _deployHarness();
        harness.callOnlyAllowedUser(bob);

        harness.setWhitelistStatus(true);
        harness.setWhitelistedUser(alice, true);

        harness.callOnlyAllowedUser(alice);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        harness.callOnlyAllowedUser(bob);
    }

    function testWhitelistDisabledAllowsNonWhitelistedUser() public {
        _listMarket(market);

        assertFalse(operator.whitelistEnabled());
        assertFalse(operator.userWhitelisted(alice));

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(alice);
        operator.enterMarkets(markets);

        assertTrue(operator.checkMembership(alice, address(market)));
    }

    function testIfNotBlacklistedReverts() public {
        _listMarket(market);
        blacklister.blacklist(alice);
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenMint(address(market), alice, bob);
    }

    function testIfNotBlacklistedAllowsWhenClean() public {
        OperatorHarness harness = _deployHarness();
        harness.callIfNotBlacklisted(alice);

        blacklister.blacklist(alice);
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        harness.callIfNotBlacklisted(alice);
    }

    function testBeforeMTokenMintRevertsWhenReceiverBlacklisted() public {
        _listMarket(market);
        blacklister.blacklist(bob);

        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenMint(address(market), alice, bob);
    }

    function testInitFirewallAndRegister() public {
        MockFirewall firewall = new MockFirewall();
        operator.initFirewall(address(firewall));
        operator.firewallRegister(alice);

        assertEq(firewall.registerCount(), 1);
        assertEq(firewall.lastRegistered(), alice);
        assertFalse(firewall.lastStrictMode());
    }

    function testSetBlacklister() public {
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(this), address(roles));
        ERC1967Proxy proxy = new ERC1967Proxy(address(blacklisterImp), initData);

        operator.setBlacklister(address(proxy));
        assertEq(address(operator.blacklistOperator()), address(proxy));
    }

    function testSetBlacklisterRevertsOnZero() public {
        vm.expectRevert(Operator.Operator_AddressNotValid.selector);
        operator.setBlacklister(address(0));
    }

    function test_fuzz_setBorrowSizeMin(uint8 len, uint256 seed, uint256 amount) public {
        vm.assume(len > 0 && len < 5);
        vm.assume(amount <= type(uint256).max - len);

        address[] memory markets = new address[](len);
        uint256[] memory amounts = new uint256[](len);
        for (uint256 i; i < len; ++i) {
            markets[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))) | 1);
            amounts[i] = amount + i;
        }

        operator.setBorrowSizeMin(markets, amounts);
        for (uint256 i; i < len; ++i) {
            assertEq(operator.minBorrowSize(markets[i]), amounts[i]);
        }
    }

    function testSetBorrowSizeMinRevertsOnMismatchedLength() public {
        address[] memory markets = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        markets[0] = address(1);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setBorrowSizeMin(markets, amounts);
    }

    function testSetWhitelistStatusDisables() public {
        operator.setWhitelistStatus(true);
        operator.setWhitelistStatus(false);
        assertFalse(operator.whitelistEnabled());
    }

    function testSetRolesOperator() public {
        Roles newRoles = new Roles(address(this));
        operator.setRolesOperator(address(newRoles));
        assertEq(address(operator.rolesOperator()), address(newRoles));
    }

    function testSetRolesOperatorRevertsOnZero() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setRolesOperator(address(0));
    }

    function testSetPriceOracleRevertsOnZero() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setPriceOracle(address(0));
    }

    function test_fuzz_setCloseFactor(uint256 closeFactor) public {
        closeFactor = bound(closeFactor, CLOSE_FACTOR_MIN, CLOSE_FACTOR_MAX);
        operator.setCloseFactor(closeFactor);
        assertEq(operator.closeFactorMantissa(), closeFactor);
    }

    function testSetCloseFactorRevertsOutOfRange() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setCloseFactor(CLOSE_FACTOR_MIN - 1);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setCloseFactor(CLOSE_FACTOR_MAX + 1);
    }

    function testSetCollateralFactorRevertsForUnlisted() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    function testSetCollateralFactorRevertsForPriceZero() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(0);
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    function testSetCollateralFactorRevertsAboveMax() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.expectRevert(OperatorStorage.Operator_InvalidCollateralFactor.selector);
        operator.setCollateralFactor(address(market), COLLATERAL_FACTOR_MAX + 1);
    }

    function testSetCollateralFactorUpdates() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        (, uint256 collateralFactor) = operator.markets(address(market));
        assertEq(collateralFactor, 0.5e18);
    }

    function testSupportMarketRevertsIfAlreadyListed() public {
        _listMarket(market);
        vm.expectRevert(OperatorStorage.Operator_MarketAlreadyListed.selector);
        operator.supportMarket(address(market));
    }

    function testSupportMarketRevertsIfAlreadyInAllMarkets() public {
        OperatorHarness harnessImpl = new OperatorHarness();
        bytes memory initData =
            abi.encodeWithSelector(Operator.initialize.selector, address(roles), address(blacklister), address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(address(harnessImpl), initData);
        OperatorHarness harness = OperatorHarness(address(proxy));

        harness.pushAllMarkets(address(market));
        harness.setMarketListed(address(market), false);

        vm.expectRevert(OperatorStorage.Operator_MarketAlreadyListed.selector);
        harness.supportMarket(address(market));
    }

    function testFuzzSetOutflowVolumeTimeWindow(uint256 newTimeWindow) public {
        vm.assume(newTimeWindow > 0);
        operator.setOutflowVolumeTimeWindow(newTimeWindow);
        assertEq(operator.outflowResetTimeWindow(), newTimeWindow);
    }

    function testSetOutflowVolumeTimeWindowRevertsOnZero() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setOutflowVolumeTimeWindow(0);
    }

    function testResetOutflowVolume() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(10);
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        vm.warp(block.timestamp + 1 hours);
        operator.resetOutflowVolume();

        assertEq(operator.cumulativeOutflowVolume(), 0);
        assertEq(operator.lastOutflowResetTimestamp(), block.timestamp);
    }

    function testCheckOutflowVolumeLimitRevertsWhenMarketNotListed() public {
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.checkOutflowVolumeLimit(1);
    }

    function testCheckOutflowVolumeLimitDisabledDoesNothing() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);
        assertEq(operator.cumulativeOutflowVolume(), 0);
    }

    function testCheckOutflowVolumeLimitResetsWindowAndUpdates() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(10);
        operator.setOutflowVolumeTimeWindow(1);

        vm.warp(block.timestamp + 2);
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        assertEq(operator.lastOutflowResetTimestamp(), block.timestamp);
        assertEq(operator.cumulativeOutflowVolume(), 1);
    }

    function testCheckOutflowVolumeLimitDoesNotResetWithinWindow() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(10);

        uint256 lastReset = operator.lastOutflowResetTimestamp();
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        assertEq(operator.lastOutflowResetTimestamp(), lastReset);
        assertEq(operator.cumulativeOutflowVolume(), 1);
    }

    function testCheckOutflowVolumeLimitRevertsWhenOverLimit() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(1);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);
        operator.checkOutflowVolumeLimit(2e10);
    }

    function testCheckOutflowVolumeLimitRevertsWhenOracleZero() public {
        _listMarket(market);
        operator.setOutflowTimeLimitInUSD(1);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_OracleUnderlyingFetchError.selector);
        operator.checkOutflowVolumeLimit(1);
    }

    function testSetMarketBorrowCapsGuardian() public {
        roles.allowFor(guardian, roles.GUARDIAN_BORROW_CAP(), true);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(guardian);
        operator.setMarketBorrowCaps(markets, caps);
        assertEq(operator.borrowCaps(address(market)), 100);
    }

    function testSetMarketBorrowCapsOwner() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 55;

        operator.setMarketBorrowCaps(markets, caps);
        assertEq(operator.borrowCaps(address(market)), 55);
    }

    function testSetMarketBorrowCapsRevertsForNonGuardian() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    function testSetMarketBorrowCapsRevertsOnInvalidInput() public {
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    function testSetMarketBorrowCapsRevertsOnMismatchedLengths() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](2);
        markets[0] = address(market);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    function testSetMarketSupplyCapsGuardian() public {
        roles.allowFor(guardian, roles.GUARDIAN_SUPPLY_CAP(), true);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(guardian);
        operator.setMarketSupplyCaps(markets, caps);
        assertEq(operator.supplyCaps(address(market)), 100);
    }

    function testSetMarketSupplyCapsOwner() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 77;

        operator.setMarketSupplyCaps(markets, caps);
        assertEq(operator.supplyCaps(address(market)), 77);
    }

    function testSetMarketSupplyCapsRevertsForNonGuardian() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    function testSetMarketSupplyCapsRevertsOnInvalidInput() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](0);
        markets[0] = address(market);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    function testSetMarketSupplyCapsRevertsOnEmptyArrays() public {
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    function testSetMarketCapsRevertsForUnauthorizedAndInvalidInputs() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 1;

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory capsMismatch = new uint256[](2);
        capsMismatch[0] = 1;
        capsMismatch[1] = 2;
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, capsMismatch);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketSupplyCaps(markets, caps);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, capsMismatch);
    }

    function testCapsAndPauseGuardsRevert() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 1;

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory capsMismatch = new uint256[](2);
        capsMismatch[0] = 1;
        capsMismatch[1] = 2;
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, capsMismatch);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketSupplyCaps(markets, caps);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, capsMismatch);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);
    }

    function testAdminActionsSucceedWithFirewallEnabled() public {
        _enableFirewall();

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 123;

        operator.setMarketBorrowCaps(markets, caps);
        assertEq(operator.borrowCaps(address(market)), 123);

        caps[0] = 456;
        operator.setMarketSupplyCaps(markets, caps);
        assertEq(operator.supplyCaps(address(market)), 456);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        assertTrue(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Mint));

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);
        assertFalse(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Mint));
    }

    function testSetPausedGuardianCanPauseOwnerUnpauses() public {
        roles.allowFor(guardian, roles.GUARDIAN_PAUSE(), true);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        vm.prank(guardian);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        assertTrue(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Mint));

        vm.prank(guardian);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);
        assertFalse(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Mint));
    }

    function testSetPausedRevertsWhenPausingWithoutRole() public {
        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
    }

    function testSetPausedRevertsForUnauthorizedPauseAndUnpause() public {
        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);
    }

    function testSetPausedOwnerCanPause() public {
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        assertTrue(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Borrow));
    }

    function testInitializeRevertsOnInvalidInputs() public {
        Operator operatorImpl = new Operator();
        ERC1967Proxy proxy = new ERC1967Proxy(address(operatorImpl), "");
        Operator freshOperator = Operator(address(proxy));

        vm.expectRevert(OperatorStorage.Operator_InvalidRolesOperator.selector);
        freshOperator.initialize(address(0), address(blacklister), address(this));

        vm.expectRevert(OperatorStorage.Operator_InvalidBlacklistOperator.selector);
        freshOperator.initialize(address(roles), address(0), address(this));

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        freshOperator.initialize(address(roles), address(blacklister), address(0));
    }

    function testEnterMarketsWithSenderRequiresListed() public {
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.enterMarketsWithSender(alice);
    }

    function testEnterMarketsWithSenderAddsMembership() public {
        _listMarket(market);
        vm.prank(address(market));
        operator.enterMarketsWithSender(alice);
        assertTrue(operator.checkMembership(alice, address(market)));
    }

    function testEnterMarketsWithSenderRevertsWhenWhitelistEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.enterMarketsWithSender(alice);
    }

    function testEnterMarketsRevertsWhenMarketNotListed() public {
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.enterMarkets(markets);
    }

    function testEnterMarketsAddsAssetAndGetAssetsIn() public {
        _listMarket(market);
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(alice);
        operator.enterMarkets(markets);

        address[] memory assets = operator.getAssetsIn(alice);
        assertEq(assets.length, 1);
        assertEq(assets[0], address(market));
    }

    function testGetAllMarketsReturnsList() public {
        _listMarket(market);
        _listMarket(market2);

        address[] memory markets = operator.getAllMarkets();
        assertEq(markets.length, 2);
        assertEq(markets[0], address(market));
        assertEq(markets[1], address(market2));
    }

    function testExitMarketReturnsWhenNotMember() public {
        _listMarket(market);
        vm.prank(alice);
        operator.exitMarket(address(market));
        assertFalse(operator.checkMembership(alice, address(market)));
    }

    function testExitMarketRevertsWhenBorrowOwed() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 1, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_Deactivate_MarketBalanceOwed.selector);
        operator.exitMarket(address(market));
    }

    function testExitMarketRevertsWhenBorrowOwedWithFirewall() public {
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 1, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_Deactivate_MarketBalanceOwed.selector);
        operator.exitMarket(address(market));
    }

    function testExitMarketRevertsWhenAssetNotFound() public {
        OperatorHarness harnessImpl = new OperatorHarness();
        bytes memory initData =
            abi.encodeWithSelector(Operator.initialize.selector, address(roles), address(blacklister), address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(address(harnessImpl), initData);
        OperatorHarness harness = OperatorHarness(address(proxy));

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), alice, true);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);
        harness.exitMarket(address(market));
    }

    function testExitMarketRevertsWhenAssetNotFoundWithNonEmptyAssets() public {
        OperatorHarness harness = _deployHarness();
        MockMToken otherMarket = new MockMToken();

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), alice, true);
        harness.setPriceOracle(address(oracleOperator));
        oracleOperator.setUnderlyingPrice(1e18);

        address[] memory assets = new address[](1);
        assets[0] = address(otherMarket);
        harness.setAccountAssets(alice, assets);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);
        harness.exitMarket(address(market));
    }

    function testExitMarketRevertsWhenAssetMissingAndTransferPaused() public {
        OperatorHarness harness = _deployHarness();
        harness.setPriceOracle(address(oracleOperator));
        oracleOperator.setUnderlyingPrice(1e18);

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), alice, true);

        vm.prank(alice);
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);
        harness.exitMarket(address(market));

        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenTransfer(address(market), alice, bob, 1);
    }

    function testExitMarketRemovesAsset() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.prank(alice);
        operator.exitMarket(address(market));
        assertFalse(operator.checkMembership(alice, address(market)));
        assertEq(operator.getAssetsIn(alice).length, 0);
    }

    function testEnterExitMarketsSucceedWithFirewallEnabled() public {
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.prank(alice);
        operator.exitMarket(address(market));
        assertEq(operator.getAssetsIn(alice).length, 0);
    }

    function testExitMarketRemovesMiddleAsset() public {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        operator.setCollateralFactor(address(market2), 0);
        market.setSnapshot(alice, 10, 0, 1e18);
        market2.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(market2);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.prank(alice);
        operator.exitMarket(address(market));

        assertFalse(operator.checkMembership(alice, address(market)));
        address[] memory assets = operator.getAssetsIn(alice);
        assertEq(assets.length, 1);
        assertEq(assets[0], address(market2));
    }

    function testBeforeMTokenTransferRevertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenTransfer(address(market), alice, bob, 1);
    }

    function testBeforeMTokenTransferAccruesInterest() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        operator.beforeMTokenTransfer(address(market), alice, bob, 10);
        assertTrue(market.accrueInterestCalled());
    }

    function testBeforeOpsRevertWhenPaused() public {
        _listMarket(market);
        _listMarket(market2);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenTransfer(address(market), alice, bob, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), alice, bob);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), alice);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeRebalancing(address(market));
    }

    function testBeforeOpsSucceedWithFirewallEnabled() public {
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;
        operator.setMarketBorrowCaps(markets, caps);

        operator.beforeMTokenTransfer(address(market), alice, bob, 1);

        market.setTotals(1, 0, 0);
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), alice, 1);

        operator.beforeMTokenMint(address(market), alice, bob);
        operator.beforeMTokenRepay(address(market), alice);
    }

    function testBeforeMTokenTransferRevertsWhenReceiverBlacklisted() public {
        _listMarket(market);
        blacklister.blacklist(bob);

        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenTransfer(address(market), alice, bob, 1);
    }

    function testBeforeMTokenBorrowRevertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowRevertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowRevertsWhenSenderNotToken() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowRevertsWhenWhitelistEnabledAndNotWhitelisted() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowSucceedsWhenWhitelistedEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(alice, true);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 2, 0, 1e18);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 10;
        operator.setMarketBorrowCaps(markets, caps);

        market.setTotals(1, 0, 0);
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowRevertsWhenPriceZero() public {
        _listMarket(market);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowRevertsWhenBorrowCapReached() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;
        operator.setMarketBorrowCaps(markets, caps);

        market.setTotals(100, 0, 0);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowSucceedsWhenBorrowCapZero() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(alice, true);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 2, 0, 1e18);
        market.setTotals(1, 0, 0);

        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowRevertsWhenBorrowSizeNotMet() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        address[] memory markets = new address[](1);
        uint256[] memory mins = new uint256[](1);
        markets[0] = address(market);
        mins[0] = 100;
        operator.setBorrowSizeMin(markets, mins);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowSizeNotMet.selector);
        operator.beforeMTokenBorrow(address(market), alice, 50);
    }

    function testBeforeMTokenBorrowRevertsWhenInsufficientLiquidity() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 0, 0, 1e18);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowRevertsForChecks() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenBorrow(address(market2), alice, 1);

        vm.prank(bob);
        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        oracleOperator.setUnderlyingPrice(0);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        oracleOperator.setUnderlyingPrice(1e18);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 5;
        operator.setMarketBorrowCaps(markets, caps);
        market.setTotals(5, 0, 0);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        caps[0] = 0;
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory mins = new uint256[](1);
        mins[0] = 10;
        operator.setBorrowSizeMin(markets, mins);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowSizeNotMet.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        mins[0] = 0;
        operator.setBorrowSizeMin(markets, mins);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 0, 0, 1e18);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenBorrowMintRepayRevertsForGuardChecks() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenBorrow(address(market2), alice, 1);

        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        oracleOperator.setUnderlyingPrice(0);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        oracleOperator.setUnderlyingPrice(1e18);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 10;
        operator.setMarketBorrowCaps(markets, caps);
        market.setTotals(10, 0, 0);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        caps[0] = 0;
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory mins = new uint256[](1);
        mins[0] = 10;
        operator.setBorrowSizeMin(markets, mins);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowSizeNotMet.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        mins[0] = 0;
        operator.setBorrowSizeMin(markets, mins);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 0, 0, 1e18);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenBorrow(address(market), alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), alice, bob);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenMint(address(market2), alice, bob);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenRepay(address(market2), alice);
    }

    function testBeforeMTokenBorrowSucceeds() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 2, 0, 1e18);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 10;
        operator.setMarketBorrowCaps(markets, caps);

        market.setTotals(1, 0, 0);
        assertFalse(operator.checkMembership(alice, address(market)));
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), alice, 1);
        assertTrue(operator.checkMembership(alice, address(market)));
    }

    function testBeforeMTokenBorrowSucceedsWhenAlreadyMemberAndCallerNotToken() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.prank(bob);
        operator.beforeMTokenBorrow(address(market), alice, 1);
    }

    function testBeforeMTokenMintRevertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), alice, bob);
    }

    function testBeforeMTokenMintRevertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenMint(address(market), alice, bob);
    }

    function testBeforeMTokenMintRevertsWhenWhitelistEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenMint(address(market), alice, bob);
    }

    function testBeforeMTokenMintAndRepayRevertChecks() public {
        _listMarket(market);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), alice, bob);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenMint(address(market2), alice, bob);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenRepay(address(market2), alice);
    }

    function testBeforeMTokenMintSucceedsWhenWhitelisted() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(alice, true);

        operator.beforeMTokenMint(address(market), alice, bob);
    }

    function testBeforeMTokenMintSucceeds() public {
        _listMarket(market);
        operator.beforeMTokenMint(address(market), alice, bob);
    }

    function testAfterMTokenMintRevertsWhenSupplyCapExceeded() public {
        _listMarket(market);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 1;
        operator.setMarketSupplyCaps(markets, caps);
        market.setTotals(0, 2, 0);
        market.setExchangeRateStored(1e18);

        vm.expectRevert(OperatorStorage.Operator_MarketSupplyReached.selector);
        operator.afterMTokenMint(address(market));
    }

    function testAfterMTokenMintSucceedsWithinSupplyCap() public {
        _listMarket(market);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;
        operator.setMarketSupplyCaps(markets, caps);
        market.setTotals(0, 10, 0);
        market.setExchangeRateStored(1e18);

        operator.afterMTokenMint(address(market));
    }

    function testBeforeMTokenRedeemSkipsWhenNotInMarket() public {
        _listMarket(market);
        operator.beforeMTokenRedeem(address(market), alice, 1);
    }

    function testBeforeMTokenRedeemRevertsWhenWhitelistEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenRedeem(address(market), alice, 1);
    }

    function testBeforeMTokenRedeemRevertsOnShortfall() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 0, 10, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenRedeem(address(market), alice, 1);
    }

    function testBeforeMTokenRedeemSucceedsWhenInMarket() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        operator.beforeMTokenRedeem(address(market), alice, 1);
    }

    function testBeforeMTokenRepayRevertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), alice);
    }

    function testBeforeMTokenRepayRevertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenRepay(address(market), alice);
    }

    function testBeforeMTokenRepayRevertsWhenWhitelistEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenRepay(address(market), alice);
    }

    function testBeforeMTokenRepaySucceedsWhenWhitelisted() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(alice, true);

        operator.beforeMTokenRepay(address(market), alice);
    }

    function testBeforeMTokenRepaySucceeds() public {
        _listMarket(market);
        operator.beforeMTokenRepay(address(market), alice);
    }

    function testBeforeMTokenLiquidateDeprecatedRequiresFullRepay() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 100);
    }

    function testBeforeMTokenLiquidateDeprecatedRepayAmountChecks() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 100);
    }

    function testBeforeMTokenLiquidateRevertsForListingChecks() public {
        MockMToken unlistedBorrowed = new MockMToken();
        MockMToken unlistedCollateral = new MockMToken();

        _listMarket(market);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(unlistedBorrowed), address(market), alice, 1);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(unlistedCollateral), alice, 1);
    }

    function testBeforeMTokenLiquidateRevertsWhenNoShortfall() public {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market2), 0.5e18);
        market2.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market2);
        vm.prank(alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(alice, 10);
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);
    }

    function testBeforeMTokenLiquidateRevertsForShortfallAndCloseFactor() public {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market2), 0.5e18);
        market2.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market2);
        vm.prank(alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(alice, 10);
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);

        operator.setCollateralFactor(address(market2), 0);
        market2.setSnapshot(alice, 0, 100, 1e18);
        market.setBorrowBalanceStored(alice, 100);
        operator.setCloseFactor(0.5e18);

        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 60);
    }

    function testBeforeMTokenLiquidateRevertsForDeprecatedAndShortfallChecks() public {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, false);

        MockMToken unlistedMarket = new MockMToken();
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(unlistedMarket), address(market2), alice, 1);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(unlistedMarket), alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 100);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);
        market.setReserveFactorMantissa(0);

        operator.setCollateralFactor(address(market2), 0.5e18);
        market2.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market2);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);

        operator.setCollateralFactor(address(market2), 0);
        market.setSnapshot(bob, 0, 100, 1e18);
        market.setBorrowBalanceStored(bob, 100);

        address[] memory marketsBob = new address[](1);
        marketsBob[0] = address(market);
        vm.prank(bob);
        operator.enterMarkets(marketsBob);

        operator.setCloseFactor(0.5e18);
        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), bob, 60);
    }

    function testBeforeMTokenLiquidateRevertsWhenPaused() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);
    }

    function testBeforeMTokenLiquidateRevertsWhenBorrowedNotListed() public {
        _listMarket(market2);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);
    }

    function testBeforeMTokenLiquidateRevertsWhenCollateralNotListed() public {
        _listMarket(market);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 1);
    }

    function testBeforeMTokenLiquidateRevertsWhenRepayingTooMuch() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 0, 100, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(alice, 100);
        operator.setCloseFactor(0.5e18);

        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);
        operator.beforeMTokenLiquidate(address(market), address(market), alice, 60);
    }

    function testBeforeMTokenLiquidateSucceedsWithCloseFactor() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 0, 100, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(alice, 100);
        operator.setCloseFactor(0.5e18);

        operator.beforeMTokenLiquidate(address(market), address(market), alice, 50);
    }

    function testLiquidationSeizeRebalanceSucceedWithFirewallEnabled() public {
        _enableFirewall();
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 0, 100, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(alice, 100);
        operator.setCloseFactor(0.5e18);

        operator.beforeMTokenLiquidate(address(market), address(market2), alice, 50);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
        operator.beforeRebalancing(address(market));
    }

    function testBeforeMTokenSeizeRevertsWhenPaused() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
    }

    function testBeforeMTokenSeizeRevertsWhenBorrowedPaused() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market2), ImTokenOperationTypes.OperationType.Seize, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
    }

    function testBeforeMTokenSeizeRevertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
    }

    function testBeforeMTokenSeizeRevertsWhenCollateralNotListed() public {
        _listMarket(market2);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
    }

    function testBeforeMTokenSeizeRevertsWhenOperatorsMismatch() public {
        _listMarket(market);
        _listMarket(market2);
        market.setOperator(address(0xB));
        market2.setOperator(address(0xC));

        vm.expectRevert(OperatorStorage.Operator_Mismatch.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
    }

    function testBeforeMTokenSeizeRevertsForPauseListingAndMismatch() public {
        _listMarket(market);
        _listMarket(market2);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, false);

        MockMToken unlistedMarket = new MockMToken();
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(unlistedMarket), address(market2), alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(unlistedMarket), alice);

        market.setOperator(address(0xB));
        market2.setOperator(address(0xC));
        vm.expectRevert(OperatorStorage.Operator_Mismatch.selector);
        operator.beforeMTokenSeize(address(market), address(market2), alice);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeRebalancing(address(market));
    }

    function testBeforeMTokenSeizeRevertsForListingChecks() public {
        MockMToken unlistedMarket = new MockMToken();

        _listMarket(market);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(unlistedMarket), alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(unlistedMarket), address(market), alice);
    }

    function testBeforeMTokenSeizeSucceeds() public {
        _listMarket(market);
        _listMarket(market2);
        operator.beforeMTokenSeize(address(market), address(market2), alice);
    }

    function testGetHypotheticalAccountLiquidity() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        (uint256 liquidity, uint256 shortfall) = operator.getHypotheticalAccountLiquidity(alice, address(0), 0, 0);
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function testGetHypotheticalAccountLiquidityRevertsWhenOracleZero() public {
        _listMarket(market);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(alice);
        operator.enterMarkets(markets);

        vm.expectRevert(OperatorStorage.Operator_OracleUnderlyingFetchError.selector);
        operator.getHypotheticalAccountLiquidity(alice, address(0), 0, 0);
    }

    function testGetUSDValueForAllMarketsSkipsDeprecated() public {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        market.setTotals(0, 0, 5e10);

        operator.setPaused(address(market2), ImTokenOperationTypes.OperationType.Borrow, true);
        market2.setReserveFactorMantissa(1e18);
        market2.setTotals(0, 0, 5e10);

        uint256 total = operator.getUSDValueForAllMarkets();
        assertEq(total, 5);
    }

    function testIsDeprecatedAndIsMarketListed() public {
        _listMarket(market);
        assertTrue(operator.isMarketListed(address(market)));
        assertFalse(operator.isDeprecated(address(market)));

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        assertTrue(operator.isDeprecated(address(market)));
    }

    function testBeforeRebalancingRevertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeRebalancing(address(market));
    }

    function testBeforeRebalancingSucceeds() public {
        _listMarket(market);
        operator.beforeRebalancing(address(market));
    }
}
