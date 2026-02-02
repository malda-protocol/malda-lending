// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Blacklister} from "src/blacklister/Blacklister.sol";
import {ImTokenOperationTypes} from "src/interfaces/ImToken.sol";
import {IBlacklister} from "src/interfaces/IBlacklister.sol";
import {HypernativeFirewallProtected} from "src/libraries/HypernativeFirewallProtected.sol";
import {Operator} from "src/Operator/Operator.sol";
import {OperatorStorage} from "src/Operator/OperatorStorage.sol";
import {Roles} from "src/Roles.sol";

import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {MockMToken} from "test/mocks/MockMToken.sol";
import {BaseUnitTest} from "test/v2/utils/BaseUnitTest.t.sol";

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

contract OperatorTest is BaseUnitTest {
    uint256 private constant CLOSE_FACTOR_MIN = 0.05e18;
    uint256 private constant CLOSE_FACTOR_MAX = 0.9e18;
    uint256 private constant COLLATERAL_FACTOR_MAX = 0.9e18;

    MockMToken internal market;
    MockMToken internal market2;
    address internal guardian;

    function setUp() public override {
        super.setUp();

        market = new MockMToken();
        market2 = new MockMToken();
        market.setOperator(address(operator));
        market2.setOperator(address(operator));
        vm.label(address(market), "MockMarket");
        vm.label(address(market2), "MockMarket2");

        guardian = users.guardian;
        vm.label(guardian, "Guardian");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _listMarket(MockMToken mToken) internal {
        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.MarketListed(address(mToken));
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

        vm.expectEmit(true, true, false, true, address(operator));
        emit HypernativeFirewallProtected.FirewallAdminChanged(address(0), address(this));
        vm.expectEmit(true, true, false, true, address(operator));
        emit HypernativeFirewallProtected.FirewallAddressChanged(address(0), address(firewall));

        operator.initFirewall(address(firewall));
        return firewall;
    }

    function _supportMarketAndJoin(MockMToken mToken, address account) internal {
        if (!operator.isMarketListed(address(mToken))) {
            _listMarket(mToken);
        }

        address[] memory markets = new address[](1);
        markets[0] = address(mToken);

        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketEntered(address(mToken), account);

        vm.prank(account);
        operator.enterMarkets(markets);
    }

    function _supportMarketAndJoin(address account, MockMToken first, MockMToken second) internal {
        if (!operator.isMarketListed(address(first))) {
            _listMarket(first);
        }
        if (!operator.isMarketListed(address(second))) {
            _listMarket(second);
        }

        address[] memory markets = new address[](2);
        markets[0] = address(first);
        markets[1] = address(second);

        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketEntered(address(first), account);

        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketEntered(address(second), account);

        vm.prank(account);
        operator.enterMarkets(markets);
    }

    function _setBorrowCaps(MockMToken mToken, uint256 cap) internal {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(mToken);
        caps[0] = cap;

        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.NewBorrowCap(address(mToken), cap);

        operator.setMarketBorrowCaps(markets, caps);
    }

    function _setBorrowSizeMin(MockMToken mToken, uint256 amount) internal {
        address[] memory markets = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        markets[0] = address(mToken);
        amounts[0] = amount;

        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.MinBorrowSizeSet(markets, amounts);

        operator.setBorrowSizeMin(markets, amounts);
    }

    function _setSupplyCaps(MockMToken mToken, uint256 cap) internal {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(mToken);
        caps[0] = cap;

        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.NewSupplyCap(address(mToken), cap);

        operator.setMarketSupplyCaps(markets, caps);
    }

    function _setWhitelistStatus(Operator target, bool status) internal {
        vm.expectEmit(false, false, false, true, address(target));
        if (status) {
            emit OperatorStorage.WhitelistEnabled();
        } else {
            emit OperatorStorage.WhitelistDisabled();
        }

        target.setWhitelistStatus(status);
    }

    function _setWhitelistedUser(Operator target, address user, bool state) internal {
        vm.expectEmit(true, false, false, true, address(target));
        emit OperatorStorage.UserWhitelisted(user, state);

        target.setWhitelistedUser(user, state);
    }

    function _setOutflowTimeLimitInUSD(uint256 amount) internal {
        uint256 previous = operator.limitPerTimePeriod();

        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.OutflowLimitUpdated(address(this), previous, amount);

        operator.setOutflowTimeLimitInUSD(amount);
    }

    function _setOutflowVolumeTimeWindow(uint256 newTimeWindow) internal {
        uint256 previous = operator.outflowResetTimeWindow();

        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.OutflowTimeWindowUpdated(previous, newTimeWindow);

        operator.setOutflowVolumeTimeWindow(newTimeWindow);
    }

    function _setPriceOracle(Operator target, address newOracle) internal {
        address previous = target.oracleOperator();

        vm.expectEmit(true, true, false, true, address(target));
        emit OperatorStorage.NewPriceOracle(previous, newOracle);

        target.setPriceOracle(newOracle);
    }

    function _setCloseFactor(uint256 newCloseFactor) internal {
        uint256 previous = operator.closeFactorMantissa();

        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.NewCloseFactor(previous, newCloseFactor);

        operator.setCloseFactor(newCloseFactor);
    }

    function _setCollateralFactor(MockMToken mToken, uint256 newCollateralFactor) internal {
        (, uint256 previous) = operator.markets(address(mToken));

        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.NewCollateralFactor(address(mToken), previous, newCollateralFactor);

        operator.setCollateralFactor(address(mToken), newCollateralFactor);
    }

    function _setPaused(address mToken, ImTokenOperationTypes.OperationType operation, bool state) internal {
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.ActionPaused(mToken, operation, state);

        operator.setPaused(mToken, operation, state);
    }

    function _setPausedAs(address caller, address mToken, ImTokenOperationTypes.OperationType operation, bool state)
        internal
    {
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.ActionPaused(mToken, operation, state);

        vm.prank(caller);
        operator.setPaused(mToken, operation, state);
    }

    function _allowRole(address target, bytes32 role, bool allowed) internal {
        vm.expectEmit(true, true, false, true, address(roles));
        emit Roles.Allowed(target, role, allowed);

        roles.allowFor(target, role, allowed);
    }

    function _blacklist(address user) internal {
        vm.expectEmit(true, false, false, true, address(blacklister));
        emit IBlacklister.Blacklisted(user);

        blacklister.blacklist(user);
    }

    ////////////////////////////////////////////////////////////
    //                 enterMarketsWithSender                 //
    ////////////////////////////////////////////////////////////

    function test_unit_enterMarketsWithSender_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketEntered(address(market), users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    function test_unit_enterMarketsWithSender_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);
    }

    function test_unit_enterMarketsWithSender_revertsWith_Operator_UserNotWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);
    }

    function test_unit_enterMarketsWithSender_success_whenWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);
        _setWhitelistedUser(operator, users.alice, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketEntered(address(market), users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //                  callOnlyAllowedUser                   //
    ////////////////////////////////////////////////////////////

    function test_unit_callOnlyAllowedUser_revertsWith_Operator_UserNotWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        OperatorHarness harness = _deployHarness();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callOnlyAllowedUser(users.bob);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setWhitelistStatus(harness, true);
        _setWhitelistedUser(harness, users.alice, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callOnlyAllowedUser(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callOnlyAllowedUser(users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                    checkMembership                     //
    ////////////////////////////////////////////////////////////

    function test_unit_checkMembership_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(operator.whitelistEnabled());
        assertFalse(operator.userWhitelisted(users.alice));
        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //                    beforeMTokenMint                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenMint_revertsWith_Operator_UserBlacklisted_onSender() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _blacklist(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_revertsWith_Operator_UserBlacklisted_onReceiver() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _blacklist(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_revertsWith_Operator_Paused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_revertsWith_Operator_UserNotWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_success_whenWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);
        _setWhitelistedUser(operator, users.alice, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                  callIfNotBlacklisted                  //
    ////////////////////////////////////////////////////////////

    function test_unit_callIfNotBlacklisted_revertsWith_Operator_UserBlacklisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        OperatorHarness harness = _deployHarness();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callIfNotBlacklisted(users.alice);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _blacklist(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.callIfNotBlacklisted(users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                    firewallRegister                    //
    ////////////////////////////////////////////////////////////

    function test_unit_firewallRegister_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockFirewall firewall = new MockFirewall();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.initFirewall(address(firewall));
        operator.firewallRegister(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(firewall.registerCount(), 1);
        assertEq(firewall.lastRegistered(), users.alice);
        assertFalse(firewall.lastStrictMode());
    }

    ////////////////////////////////////////////////////////////
    //                     setBlacklister                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setBlacklister_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(this), address(roles));
        ERC1967Proxy proxy = new ERC1967Proxy(address(blacklisterImp), initData);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(operator));
        emit Operator.NewBlacklister(address(proxy));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setBlacklister(address(proxy));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(operator.blacklistOperator()), address(proxy));
    }

    function test_unit_setBlacklister_revertsWith_Operator_AddressNotValid() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(Operator.Operator_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setBlacklister(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                    setBorrowSizeMin                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setBorrowSizeMin_success(uint8 len, uint256 seed, uint256 amount) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(len > 0 && len < 5);
        vm.assume(amount <= type(uint256).max - len);

        address[] memory markets = new address[](len);
        uint256[] memory amounts = new uint256[](len);
        for (uint256 i; i < len; ++i) {
            markets[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))) | 1);
            amounts[i] = amount + i;
        }

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.MinBorrowSizeSet(markets, amounts);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setBorrowSizeMin(markets, amounts);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        for (uint256 i; i < len; ++i) {
            assertEq(operator.minBorrowSize(markets[i]), amounts[i]);
        }
    }

    function test_unit_setBorrowSizeMin_revertsWith_Operator_InvalidInput() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        markets[0] = address(1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setBorrowSizeMin(markets, amounts);
    }

    ////////////////////////////////////////////////////////////
    //                   setWhitelistStatus                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setWhitelistStatus_success() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.WhitelistEnabled();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setWhitelistStatus(true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.WhitelistDisabled();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setWhitelistStatus(false);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(operator.whitelistEnabled());
    }

    ////////////////////////////////////////////////////////////
    //                    setRolesOperator                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setRolesOperator_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Roles newRoles = new Roles(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.NewRolesOperator(address(roles), address(newRoles));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setRolesOperator(address(newRoles));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(address(operator.rolesOperator()), address(newRoles));
    }

    function test_unit_setRolesOperator_revertsWith_Operator_InvalidInput() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setRolesOperator(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     setPriceOracle                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setPriceOracle_revertsWith_Operator_InvalidInput() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setPriceOracle(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     setCloseFactor                     //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setCloseFactor_success(uint256 closeFactor) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        closeFactor = bound(closeFactor, CLOSE_FACTOR_MIN, CLOSE_FACTOR_MAX);
        uint256 previous = operator.closeFactorMantissa();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.NewCloseFactor(previous, closeFactor);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setCloseFactor(closeFactor);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.closeFactorMantissa(), closeFactor);
    }

    function test_unit_setCloseFactor_revertsWith_Operator_InvalidInput() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setCloseFactor(CLOSE_FACTOR_MIN - 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setCloseFactor(CLOSE_FACTOR_MAX + 1);
    }

    ////////////////////////////////////////////////////////////
    //                  setCollateralFactor                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setCollateralFactor_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    function test_unit_setCollateralFactor_revertsWith_Operator_EmptyPrice() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    function test_unit_setCollateralFactor_revertsWith_Operator_InvalidCollateralFactor() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidCollateralFactor.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setCollateralFactor(address(market), COLLATERAL_FACTOR_MAX + 1);
    }

    ////////////////////////////////////////////////////////////
    //                        markets                         //
    ////////////////////////////////////////////////////////////

    function test_unit_markets_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        _setCollateralFactor(market, 0.5e18);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        (, uint256 collateralFactor) = operator.markets(address(market));
        assertEq(collateralFactor, 0.5e18);
    }

    ////////////////////////////////////////////////////////////
    //                     supportMarket                      //
    ////////////////////////////////////////////////////////////

    function test_unit_supportMarket_revertsWith_Operator_MarketAlreadyListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketAlreadyListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.supportMarket(address(market));
    }

    function test_unit_supportMarket_revertsWith_Operator_MarketAlreadyListed_whenInArray() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        OperatorHarness harness = _deployHarness();
        harness.pushAllMarkets(address(market));
        harness.setMarketListed(address(market), false);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketAlreadyListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        harness.supportMarket(address(market));
    }

    ////////////////////////////////////////////////////////////
    //               setOutflowVolumeTimeWindow               //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setOutflowVolumeTimeWindow_success(uint256 newTimeWindow) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.assume(newTimeWindow > 0);
        uint256 previous = operator.outflowResetTimeWindow();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.OutflowTimeWindowUpdated(previous, newTimeWindow);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setOutflowVolumeTimeWindow(newTimeWindow);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.outflowResetTimeWindow(), newTimeWindow);
    }

    function test_unit_setOutflowVolumeTimeWindow_revertsWith_Operator_InvalidInput() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setOutflowVolumeTimeWindow(0);
    }

    ////////////////////////////////////////////////////////////
    //                   resetOutflowVolume                   //
    ////////////////////////////////////////////////////////////

    function test_unit_resetOutflowVolume_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setOutflowTimeLimitInUSD(10);

        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        vm.warp(block.timestamp + 1 hours);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(operator));
        emit OperatorStorage.OutflowVolumeReset();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.resetOutflowVolume();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.cumulativeOutflowVolume(), 0);
        assertEq(operator.lastOutflowResetTimestamp(), block.timestamp);
    }

    ////////////////////////////////////////////////////////////
    //                checkOutflowVolumeLimit                 //
    ////////////////////////////////////////////////////////////

    function test_unit_checkOutflowVolumeLimit_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1);
    }

    function test_unit_checkOutflowVolumeLimit_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.cumulativeOutflowVolume(), 0);
    }

    function test_unit_checkOutflowVolumeLimit_success_whenWindowElapsed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setOutflowTimeLimitInUSD(10);
        _setOutflowVolumeTimeWindow(1);

        vm.warp(block.timestamp + 2);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.lastOutflowResetTimestamp(), block.timestamp);
        assertEq(operator.cumulativeOutflowVolume(), 1);
    }

    function test_unit_checkOutflowVolumeLimit_success_whenWindowNotElapsed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setOutflowTimeLimitInUSD(10);

        uint256 lastReset = operator.lastOutflowResetTimestamp();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.lastOutflowResetTimestamp(), lastReset);
        assertEq(operator.cumulativeOutflowVolume(), 1);
    }

    function test_unit_checkOutflowVolumeLimit_revertsWith_Operator_OutflowVolumeReached() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setOutflowTimeLimitInUSD(1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(2e10);
    }

    function test_unit_checkOutflowVolumeLimit_revertsWith_Operator_OracleUnderlyingFetchError() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setOutflowTimeLimitInUSD(1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OracleUnderlyingFetchError.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1);
    }

    ////////////////////////////////////////////////////////////
    //                  setMarketBorrowCaps                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketBorrowCaps_success_whenGuardian() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowRole(guardian, roles.GUARDIAN_BORROW_CAP(), true);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.NewBorrowCap(address(market), 100);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        operator.setMarketBorrowCaps(markets, caps);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.borrowCaps(address(market)), 100);
    }

    function test_unit_setMarketBorrowCaps_success_whenAdmin() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 55;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.NewBorrowCap(address(market), 55);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setMarketBorrowCaps(markets, caps);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.borrowCaps(address(market)), 55);
    }

    function test_unit_setMarketBorrowCaps_revertsWith_Operator_OnlyAdminOrRole() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.setMarketBorrowCaps(markets, caps);
    }

    function test_unit_setMarketBorrowCaps_revertsWith_Operator_InvalidInput_whenEmpty() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setMarketBorrowCaps(markets, caps);
    }

    function test_unit_setMarketBorrowCaps_revertsWith_Operator_InvalidInput_whenMismatchedLengths() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](2);
        markets[0] = address(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setMarketBorrowCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //                  setMarketSupplyCaps                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketSupplyCaps_success_whenGuardian() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowRole(guardian, roles.GUARDIAN_SUPPLY_CAP(), true);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.NewSupplyCap(address(market), 100);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        operator.setMarketSupplyCaps(markets, caps);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.supplyCaps(address(market)), 100);
    }

    function test_unit_setMarketSupplyCaps_success_whenAdmin() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 77;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(operator));
        emit OperatorStorage.NewSupplyCap(address(market), 77);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setMarketSupplyCaps(markets, caps);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.supplyCaps(address(market)), 77);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_OnlyAdminOrRole() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.setMarketSupplyCaps(markets, caps);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_InvalidInput_whenEmptyCaps() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](0);
        markets[0] = address(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setMarketSupplyCaps(markets, caps);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_InvalidInput_whenEmptyArrays() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setMarketSupplyCaps(markets, caps);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_InvalidInput_whenMismatchedLengths() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](2);
        markets[0] = address(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setMarketSupplyCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //                       setPaused                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setPaused_revertsWith_Operator_OnlyAdminOrRole_whenPausing() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
    }

    function test_unit_setPaused_revertsWith_Operator_OnlyAdmin_whenUnpausingByGuardian() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowRole(guardian, roles.GUARDIAN_PAUSE(), true);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        _setPausedAs(guardian, address(market), ImTokenOperationTypes.OperationType.Mint, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);
    }

    function test_unit_setPaused_success() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.ActionPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Borrow));
    }

    function test_unit_setPaused_success_withFirewall() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.ActionPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Mint));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.ActionPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Mint));
    }

    function test_unit_setPaused_revertsWith_Operator_OnlyAdmin() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowRole(guardian, roles.GUARDIAN_PAUSE(), true);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        _setPausedAs(guardian, address(market), ImTokenOperationTypes.OperationType.Mint, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(guardian);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Mint));
    }

    function test_unit_setPaused_revertsWith_Operator_OnlyAdminOrRole() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.prank(users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);
    }

    ////////////////////////////////////////////////////////////
    //                       initialize                       //
    ////////////////////////////////////////////////////////////

    function test_unit_initialize_revertsWith_Operator_InvalidRolesOperator() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Operator operatorImpl = new Operator();
        ERC1967Proxy proxy = new ERC1967Proxy(address(operatorImpl), "");
        Operator freshOperator = Operator(address(proxy));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidRolesOperator.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        freshOperator.initialize(address(0), address(blacklister), address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidBlacklistOperator.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        freshOperator.initialize(address(roles), address(0), address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        freshOperator.initialize(address(roles), address(blacklister), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                      enterMarkets                      //
    ////////////////////////////////////////////////////////////

    function test_unit_enterMarkets_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.enterMarkets(markets);
    }

    ////////////////////////////////////////////////////////////
    //                      getAssetsIn                       //
    ////////////////////////////////////////////////////////////

    function test_unit_getAssetsIn_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory assets = operator.getAssetsIn(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(assets.length, 1);
        assertEq(assets[0], address(market));
    }

    ////////////////////////////////////////////////////////////
    //                     getAllMarkets                      //
    ////////////////////////////////////////////////////////////

    function test_unit_getAllMarkets_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        address[] memory markets = operator.getAllMarkets();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(markets.length, 2);
        assertEq(markets[0], address(market));
        assertEq(markets[1], address(market2));
    }

    ////////////////////////////////////////////////////////////
    //                       exitMarket                       //
    ////////////////////////////////////////////////////////////

    function test_unit_exitMarket_success_whenNotMember() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.exitMarket(address(market));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(operator.checkMembership(users.alice, address(market)));
    }

    function test_unit_exitMarket_revertsWith_Operator_Deactivate_MarketBalanceOwed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 1, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Deactivate_MarketBalanceOwed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.exitMarket(address(market));
    }

    function test_unit_exitMarket_revertsWith_Operator_Deactivate_MarketBalanceOwed_whenFirewallEnabled() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 1, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Deactivate_MarketBalanceOwed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.exitMarket(address(market));
    }

    function test_unit_exitMarket_revertsWith_Operator_AssetNotFound() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        OperatorHarness harness = _deployHarness();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(harness));
        emit OperatorStorage.MarketListed(address(market));

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), users.alice, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        harness.exitMarket(address(market));
    }

    function test_unit_exitMarket_revertsWith_Operator_AssetNotFound_whenAssetListMissing() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        OperatorHarness harness = _deployHarness();
        MockMToken otherMarket = new MockMToken();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(harness));
        emit OperatorStorage.MarketListed(address(market));

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), users.alice, true);
        _setPriceOracle(harness, address(oracleOperator));
        oracleOperator.setUnderlyingPrice(1e18);

        address[] memory assets = new address[](1);
        assets[0] = address(otherMarket);
        harness.setAccountAssets(users.alice, assets);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        harness.exitMarket(address(market));
    }

    function test_unit_exitMarket_success_whenNoBorrowOwed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketExited(address(market), users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.exitMarket(address(market));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(operator.checkMembership(users.alice, address(market)));
        assertEq(operator.getAssetsIn(users.alice).length, 0);
    }

    function test_unit_exitMarket_success_whenFirewallEnabled() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketExited(address(market), users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.exitMarket(address(market));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(operator.getAssetsIn(users.alice).length, 0);
    }

    function test_unit_exitMarket_success_whenMultipleMarkets() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _supportMarketAndJoin(users.alice, market, market2);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0);
        _setCollateralFactor(market2, 0);
        market.setSnapshot(users.alice, 10, 0, 1e18);
        market2.setSnapshot(users.alice, 10, 0, 1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(operator));
        emit OperatorStorage.MarketExited(address(market), users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        operator.exitMarket(address(market));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(operator.checkMembership(users.alice, address(market)));
        address[] memory assets = operator.getAssetsIn(users.alice);
        assertEq(assets.length, 1);
        assertEq(assets[0], address(market2));
    }

    ////////////////////////////////////////////////////////////
    //                  beforeMTokenTransfer                  //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenTransfer_revertsWith_Operator_AssetNotFound() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        OperatorHarness harness = _deployHarness();
        _setPriceOracle(harness, address(oracleOperator));
        oracleOperator.setUnderlyingPrice(1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true, address(harness));
        emit OperatorStorage.MarketListed(address(market));

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), users.alice, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        harness.exitMarket(address(market));
    }

    function test_unit_beforeMTokenTransfer_revertsWith_Operator_Paused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);
    }

    function test_unit_beforeMTokenTransfer_revertsWith_Operator_UserBlacklisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _blacklist(users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);
    }

    function test_unit_beforeMTokenTransfer_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 10);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(market.accrueInterestCalled());
    }

    ////////////////////////////////////////////////////////////
    //                   beforeRebalancing                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeRebalancing_revertsWith_Operator_Paused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);

        _setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenMint(address(market), users.alice, users.bob);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRepay(address(market), users.alice);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeRebalancing(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                   beforeMTokenRepay                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenRepay_success_whenBorrowFlowPrepared() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        _setBorrowCaps(market, 100);

        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);

        market.setTotals(1, 0, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        operator.beforeMTokenMint(address(market), users.alice, users.bob);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_revertsWith_Operator_Paused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_revertsWith_Operator_UserNotWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_success_whenWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);
        _setWhitelistedUser(operator, users.alice, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_success_whenMarketListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                   beforeMTokenBorrow                   //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_Paused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_SenderMustBeToken() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_UserNotWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_success_whenWhitelistEnabled() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);
        _setWhitelistedUser(operator, users.alice, true);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 2, 0, 1e18);

        _setBorrowCaps(market, 10);

        market.setTotals(1, 0, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_EmptyPrice() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_MarketBorrowCapReached() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setBorrowCaps(market, 100);

        market.setTotals(100, 0, 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_success_whenBorrowCapZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);
        _setWhitelistedUser(operator, users.alice, true);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 2, 0, 1e18);
        market.setTotals(1, 0, 0);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_MarketBorrowSizeNotMet() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setBorrowSizeMin(market, 100);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowSizeNotMet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 50);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_InsufficientLiquidity() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0);
        market.setSnapshot(users.alice, 0, 0, 1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_success_whenAlreadyMemberAndCallerNotToken() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oracleOperator.setUnderlyingPrice(1e18);
        _supportMarketAndJoin(market, users.alice);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //                     afterMTokenMint                    //
    ////////////////////////////////////////////////////////////

    function test_unit_afterMTokenMint_revertsWith_Operator_MarketSupplyReached() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setSupplyCaps(market, 1);
        market.setTotals(0, 2, 0);
        market.setExchangeRateStored(1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketSupplyReached.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.afterMTokenMint(address(market));
    }

    function test_unit_afterMTokenMint_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setSupplyCaps(market, 100);
        market.setTotals(0, 10, 0);
        market.setExchangeRateStored(1e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.afterMTokenMint(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                   beforeMTokenRedeem                   //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenRedeem_success_whenNotInMarket() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenRedeem_revertsWith_Operator_UserNotWhitelisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setWhitelistStatus(operator, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenRedeem_revertsWith_Operator_InsufficientLiquidity() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0);
        market.setSnapshot(users.alice, 0, 10, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenRedeem_success_whenInMarket() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //                 beforeMTokenLiquidate                  //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_RepayAmountNotValid() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(users.alice, 100);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 100);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockMToken unlistedBorrowed = new MockMToken();
        MockMToken unlistedCollateral = new MockMToken();

        _listMarket(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(unlistedBorrowed), address(market), users.alice, 1);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(unlistedCollateral), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_InsufficientLiquidity() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _supportMarketAndJoin(market2, users.alice);
        _setCollateralFactor(market2, 0.5e18);
        market2.setSnapshot(users.alice, 10, 0, 1e18);

        market.setBorrowBalanceStored(users.alice, 10);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_RepayingTooMuch() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _supportMarketAndJoin(market2, users.alice);
        _setCollateralFactor(market2, 0.5e18);
        market2.setSnapshot(users.alice, 10, 0, 1e18);

        market.setBorrowBalanceStored(users.alice, 10);
        _setCollateralFactor(market2, 0);
        market2.setSnapshot(users.alice, 0, 100, 1e18);
        market.setBorrowBalanceStored(users.alice, 100);
        _setCloseFactor(0.5e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 60);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_Paused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);

        _setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_MarketNotListed_whenBorrowedNotListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market2);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_MarketNotListed_whenCollateralNotListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_RepayingTooMuch_whenCloseFactorExceeded() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oracleOperator.setUnderlyingPrice(1e18);
        _supportMarketAndJoin(market, users.alice);
        _setCollateralFactor(market, 0);
        market.setSnapshot(users.alice, 0, 100, 1e18);

        market.setBorrowBalanceStored(users.alice, 100);
        _setCloseFactor(0.5e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market), users.alice, 60);
    }

    function test_unit_beforeMTokenLiquidate_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        oracleOperator.setUnderlyingPrice(1e18);
        _supportMarketAndJoin(market, users.alice);
        _setCollateralFactor(market, 0);
        market.setSnapshot(users.alice, 0, 100, 1e18);

        market.setBorrowBalanceStored(users.alice, 100);
        _setCloseFactor(0.5e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market), users.alice, 50);
    }

    ////////////////////////////////////////////////////////////
    //                   beforeRebalancing                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeRebalancing_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        _supportMarketAndJoin(market, users.alice);
        _setCollateralFactor(market, 0);
        market.setSnapshot(users.alice, 0, 100, 1e18);

        market.setBorrowBalanceStored(users.alice, 100);
        _setCloseFactor(0.5e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
        operator.beforeRebalancing(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                   beforeMTokenSeize                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenSeize_revertsWith_Operator_Paused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_Paused_whenBorrowedPaused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);
        _setPaused(address(market2), ImTokenOperationTypes.OperationType.Seize, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_MarketNotListed() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_MarketNotListed_whenCollateralNotListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market2);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_Mismatch() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);
        market.setOperator(users.bob);
        market2.setOperator(users.carol);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Mismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_MarketNotListed_whenUnlisted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockMToken unlistedMarket = new MockMToken();
        _listMarket(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(unlistedMarket), users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(unlistedMarket), address(market), users.alice);
    }

    function test_unit_beforeMTokenSeize_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //            getHypotheticalAccountLiquidity             //
    ////////////////////////////////////////////////////////////

    function test_unit_getHypotheticalAccountLiquidity_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 liquidity, uint256 shortfall) = operator.getHypotheticalAccountLiquidity(users.alice, address(0), 0, 0);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function test_unit_getHypotheticalAccountLiquidity_revertsWith_Operator_OracleUnderlyingFetchError() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        _setCollateralFactor(market, 0);
        oracleOperator.setUnderlyingPrice(0);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        _supportMarketAndJoin(market, users.alice);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_OracleUnderlyingFetchError.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.getHypotheticalAccountLiquidity(users.alice, address(0), 0, 0);
    }

    ////////////////////////////////////////////////////////////
    //                getUSDValueForAllMarkets                //
    ////////////////////////////////////////////////////////////

    function test_unit_getUSDValueForAllMarkets_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        market.setTotals(0, 0, 5e10);

        _setPaused(address(market2), ImTokenOperationTypes.OperationType.Borrow, true);
        market2.setReserveFactorMantissa(1e18);
        market2.setTotals(0, 0, 5e10);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        uint256 total = operator.getUSDValueForAllMarkets();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(total, 5);
    }

    ////////////////////////////////////////////////////////////
    //                      isDeprecated                      //
    ////////////////////////////////////////////////////////////

    function test_unit_isDeprecated_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(operator.isMarketListed(address(market)));
        assertFalse(operator.isDeprecated(address(market)));

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(operator.isDeprecated(address(market)));
    }

    ////////////////////////////////////////////////////////////
    //                   beforeRebalancing                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeRebalancing_revertsWith_Operator_Paused_whenPaused() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);
        _setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeRebalancing(address(market));
    }

    function test_unit_beforeRebalancing_success_whenListed() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _listMarket(market);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        operator.beforeRebalancing(address(market));
    }
}
