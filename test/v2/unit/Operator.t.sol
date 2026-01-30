// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BaseUnitTest} from "test/v2/utils/BaseUnitTest.t.sol";
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

    ////////////////////////////////////////////////////////////
    //                 EnterMarketsWithSender                 //
    ////////////////////////////////////////////////////////////

    function test_unit_enterMarketsWithSender_revertsWith_Operator_UserNotWhitelisted() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(users.alice);
        operator.enterMarkets(markets);
        assertTrue(operator.checkMembership(users.alice, address(market)));

        // enterMarketsWithSender does check whitelist and should revert
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.enterMarketsWithSender(users.alice);

        // After whitelisting, enterMarketsWithSender should succeed
        operator.setWhitelistedUser(users.alice, true);
        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);
        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    function test_unit_enterMarketsWithSender_success() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);

        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);

        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //                  CallOnlyAllowedUser                   //
    ////////////////////////////////////////////////////////////

    function test_unit_callOnlyAllowedUser_revertsWith_Operator_UserNotWhitelisted() public {
        OperatorHarness harness = _deployHarness();
        harness.callOnlyAllowedUser(users.bob);

        harness.setWhitelistStatus(true);
        harness.setWhitelistedUser(users.alice, true);

        harness.callOnlyAllowedUser(users.alice);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        harness.callOnlyAllowedUser(users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                    CheckMembership                     //
    ////////////////////////////////////////////////////////////

    function test_unit_checkMembership_success_variant2() public {
        _listMarket(market);

        assertFalse(operator.whitelistEnabled());
        assertFalse(operator.userWhitelisted(users.alice));

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(users.alice);
        operator.enterMarkets(markets);

        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //                    BeforeMTokenMint                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenMint_revertsWith_Operator_UserBlacklisted_ifNotBlacklistedReverts() public {
        _listMarket(market);
        blacklister.blacklist(users.alice);
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                  CallIfNotBlacklisted                  //
    ////////////////////////////////////////////////////////////

    function test_unit_callIfNotBlacklisted_revertsWith_Operator_UserBlacklisted_ifNotBlacklistedAllowsWhenClean()
        public
    {
        OperatorHarness harness = _deployHarness();
        harness.callIfNotBlacklisted(users.alice);

        blacklister.blacklist(users.alice);
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        harness.callIfNotBlacklisted(users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                    BeforeMTokenMint                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenMint_revertsWith_Operator_UserBlacklisted_revertsWhenReceiverBlacklisted() public {
        _listMarket(market);
        blacklister.blacklist(users.bob);

        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                    FirewallRegister                    //
    ////////////////////////////////////////////////////////////

    function test_unit_firewallRegister_success() public {
        MockFirewall firewall = new MockFirewall();
        operator.initFirewall(address(firewall));
        operator.firewallRegister(users.alice);

        assertEq(firewall.registerCount(), 1);
        assertEq(firewall.lastRegistered(), users.alice);
        assertFalse(firewall.lastStrictMode());
    }

    ////////////////////////////////////////////////////////////
    //                     SetBlacklister                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setBlacklister_success_variant2() public {
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(this), address(roles));
        ERC1967Proxy proxy = new ERC1967Proxy(address(blacklisterImp), initData);

        operator.setBlacklister(address(proxy));
        assertEq(address(operator.blacklistOperator()), address(proxy));
    }

    function test_unit_setBlacklister_revertsWith_Operator_AddressNotValid_revertsOnZero() public {
        vm.expectRevert(Operator.Operator_AddressNotValid.selector);
        operator.setBlacklister(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                    SetBorrowSizeMin                    //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setBorrowSizeMin_success(uint8 len, uint256 seed, uint256 amount) public {
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

    function test_unit_setBorrowSizeMin_revertsWith_Operator_InvalidInput_revertsOnMismatchedLength() public {
        address[] memory markets = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        markets[0] = address(1);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setBorrowSizeMin(markets, amounts);
    }

    ////////////////////////////////////////////////////////////
    //                   SetWhitelistStatus                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setWhitelistStatus_success() public {
        operator.setWhitelistStatus(true);
        operator.setWhitelistStatus(false);
        assertFalse(operator.whitelistEnabled());
    }

    ////////////////////////////////////////////////////////////
    //                    SetRolesOperator                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setRolesOperator_success_variant3() public {
        Roles newRoles = new Roles(address(this));
        operator.setRolesOperator(address(newRoles));
        assertEq(address(operator.rolesOperator()), address(newRoles));
    }

    function test_unit_setRolesOperator_revertsWith_Operator_InvalidInput_revertsOnZero() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setRolesOperator(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     SetPriceOracle                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setPriceOracle_revertsWith_Operator_InvalidInput_revertsOnZero() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setPriceOracle(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     SetCloseFactor                     //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setCloseFactor_success(uint256 closeFactor) public {
        closeFactor = bound(closeFactor, CLOSE_FACTOR_MIN, CLOSE_FACTOR_MAX);
        operator.setCloseFactor(closeFactor);
        assertEq(operator.closeFactorMantissa(), closeFactor);
    }

    function test_unit_setCloseFactor_revertsWith_Operator_InvalidInput_revertsOutOfRange() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setCloseFactor(CLOSE_FACTOR_MIN - 1);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setCloseFactor(CLOSE_FACTOR_MAX + 1);
    }

    ////////////////////////////////////////////////////////////
    //                  SetCollateralFactor                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setCollateralFactor_revertsWith_Operator_MarketNotListed_revertsForUnlisted() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    function test_unit_setCollateralFactor_revertsWith_Operator_EmptyPrice_revertsForPriceZero() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(0);
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    function test_unit_setCollateralFactor_revertsWith_Operator_InvalidCollateralFactor_revertsAboveMax() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.expectRevert(OperatorStorage.Operator_InvalidCollateralFactor.selector);
        operator.setCollateralFactor(address(market), COLLATERAL_FACTOR_MAX + 1);
    }

    ////////////////////////////////////////////////////////////
    //                        Markets                         //
    ////////////////////////////////////////////////////////////

    function test_unit_markets_success() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        (, uint256 collateralFactor) = operator.markets(address(market));
        assertEq(collateralFactor, 0.5e18);
    }

    ////////////////////////////////////////////////////////////
    //                     SupportMarket                      //
    ////////////////////////////////////////////////////////////

    function test_unit_supportMarket_revertsWith_Operator_MarketAlreadyListed_revertsIfAlreadyListed() public {
        _listMarket(market);
        vm.expectRevert(OperatorStorage.Operator_MarketAlreadyListed.selector);
        operator.supportMarket(address(market));
    }

    function test_unit_supportMarket_revertsWith_Operator_MarketAlreadyListed() public {
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

    ////////////////////////////////////////////////////////////
    //               SetOutflowVolumeTimeWindow               //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setOutflowVolumeTimeWindow_success(uint256 newTimeWindow) public {
        vm.assume(newTimeWindow > 0);
        operator.setOutflowVolumeTimeWindow(newTimeWindow);
        assertEq(operator.outflowResetTimeWindow(), newTimeWindow);
    }

    function test_unit_setOutflowVolumeTimeWindow_revertsWith_Operator_InvalidInput_revertsOnZero() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setOutflowVolumeTimeWindow(0);
    }

    ////////////////////////////////////////////////////////////
    //                   ResetOutflowVolume                   //
    ////////////////////////////////////////////////////////////

    function test_unit_resetOutflowVolume_success() public {
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

    ////////////////////////////////////////////////////////////
    //                CheckOutflowVolumeLimit                 //
    ////////////////////////////////////////////////////////////

    function test_unit_checkOutflowVolumeLimit_revertsWith_Operator_MarketNotListed_revertsWhenMarketNotListed()
        public
    {
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.checkOutflowVolumeLimit(1);
    }

    function test_unit_checkOutflowVolumeLimit_success() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);
        assertEq(operator.cumulativeOutflowVolume(), 0);
    }

    function test_unit_checkOutflowVolumeLimit_success_variant2() public {
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

    function test_unit_checkOutflowVolumeLimit_success_variant3() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(10);

        uint256 lastReset = operator.lastOutflowResetTimestamp();
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        assertEq(operator.lastOutflowResetTimestamp(), lastReset);
        assertEq(operator.cumulativeOutflowVolume(), 1);
    }

    function test_unit_checkOutflowVolumeLimit_revertsWith_Operator_OutflowVolumeReached_revertsWhenOverLimit() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(1);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);
        operator.checkOutflowVolumeLimit(2e10);
    }

    function test_unit_checkOutflowVolumeLimit_revertsWith_Operator_OracleUnderlyingFetchError_revertsWhenOracleZero()
        public
    {
        _listMarket(market);
        operator.setOutflowTimeLimitInUSD(1);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_OracleUnderlyingFetchError.selector);
        operator.checkOutflowVolumeLimit(1);
    }

    ////////////////////////////////////////////////////////////
    //                  SetMarketBorrowCaps                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketBorrowCaps_success() public {
        roles.allowFor(guardian, roles.GUARDIAN_BORROW_CAP(), true);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(guardian);
        operator.setMarketBorrowCaps(markets, caps);
        assertEq(operator.borrowCaps(address(market)), 100);
    }

    function test_unit_setMarketBorrowCaps_success_variant2() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 55;

        operator.setMarketBorrowCaps(markets, caps);
        assertEq(operator.borrowCaps(address(market)), 55);
    }

    function test_unit_setMarketBorrowCaps_revertsWith_Operator_OnlyAdminOrRole_revertsForNonGuardian() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    function test_unit_setMarketBorrowCaps_revertsWith_Operator_InvalidInput_revertsOnInvalidInput() public {
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    function test_unit_setMarketBorrowCaps_revertsWith_Operator_InvalidInput_revertsOnMismatchedLengths() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](2);
        markets[0] = address(market);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //                  SetMarketSupplyCaps                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketSupplyCaps_success() public {
        roles.allowFor(guardian, roles.GUARDIAN_SUPPLY_CAP(), true);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(guardian);
        operator.setMarketSupplyCaps(markets, caps);
        assertEq(operator.supplyCaps(address(market)), 100);
    }

    function test_unit_setMarketSupplyCaps_success_variant2() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 77;

        operator.setMarketSupplyCaps(markets, caps);
        assertEq(operator.supplyCaps(address(market)), 77);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_OnlyAdminOrRole_revertsForNonGuardian() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_InvalidInput_revertsOnInvalidInput() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](0);
        markets[0] = address(market);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_InvalidInput_revertsOnEmptyArrays() public {
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    function test_unit_setMarketSupplyCaps_revertsWith_Operator_OnlyAdminOrRole() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 1;

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory capsMismatch = new uint256[](2);
        capsMismatch[0] = 1;
        capsMismatch[1] = 2;
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, capsMismatch);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketSupplyCaps(markets, caps);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, capsMismatch);
    }

    ////////////////////////////////////////////////////////////
    //                       SetPaused                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setPaused_revertsWith_Operator_OnlyAdminOrRole() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 1;

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory capsMismatch = new uint256[](2);
        capsMismatch[0] = 1;
        capsMismatch[1] = 2;
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, capsMismatch);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketSupplyCaps(markets, caps);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, capsMismatch);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, false);
    }

    ////////////////////////////////////////////////////////////
    //                  SetMarketBorrowCaps                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketBorrowCaps_success_variant2_variant2() public {
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

    ////////////////////////////////////////////////////////////
    //                       SetPaused                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setPaused_revertsWith_Operator_OnlyAdmin() public {
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

    function test_unit_setPaused_revertsWith_Operator_OnlyAdminOrRole_revertsWhenPausingWithoutRole() public {
        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
    }

    function test_unit_setPaused_revertsWith_Operator_OnlyAdminOrRole_revertsForUnauthorizedPauseAndUnpause() public {
        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);
    }

    function test_unit_setPaused_success_variant2() public {
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        assertTrue(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Borrow));
    }

    ////////////////////////////////////////////////////////////
    //                       Initialize                       //
    ////////////////////////////////////////////////////////////

    function test_unit_initialize_revertsWith_Operator_InvalidRolesOperator() public {
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

    ////////////////////////////////////////////////////////////
    //                 EnterMarketsWithSender                 //
    ////////////////////////////////////////////////////////////

    function test_unit_enterMarketsWithSender_revertsWith_Operator_MarketNotListed_requiresListed() public {
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.enterMarketsWithSender(users.alice);
    }

    function test_unit_enterMarketsWithSender_success_variant3() public {
        _listMarket(market);
        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);
        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    function test_unit_enterMarketsWithSender_revertsWith_Operator_UserNotWhitelisted_revertsWhenWhitelistEnabled()
        public
    {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.enterMarketsWithSender(users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                      EnterMarkets                      //
    ////////////////////////////////////////////////////////////

    function test_unit_enterMarkets_revertsWith_Operator_MarketNotListed_revertsWhenMarketNotListed() public {
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.enterMarkets(markets);
    }

    ////////////////////////////////////////////////////////////
    //                      GetAssetsIn                       //
    ////////////////////////////////////////////////////////////

    function test_unit_getAssetsIn_success() public {
        _listMarket(market);
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(users.alice);
        operator.enterMarkets(markets);

        address[] memory assets = operator.getAssetsIn(users.alice);
        assertEq(assets.length, 1);
        assertEq(assets[0], address(market));
    }

    ////////////////////////////////////////////////////////////
    //                     GetAllMarkets                      //
    ////////////////////////////////////////////////////////////

    function test_unit_getAllMarkets_success_returnsList() public {
        _listMarket(market);
        _listMarket(market2);

        address[] memory markets = operator.getAllMarkets();
        assertEq(markets.length, 2);
        assertEq(markets[0], address(market));
        assertEq(markets[1], address(market2));
    }

    ////////////////////////////////////////////////////////////
    //                       ExitMarket                       //
    ////////////////////////////////////////////////////////////

    function test_unit_exitMarket_success_variant4() public {
        _listMarket(market);
        vm.prank(users.alice);
        operator.exitMarket(address(market));
        assertFalse(operator.checkMembership(users.alice, address(market)));
    }

    function test_unit_exitMarket_revertsWith_Operator_Deactivate_MarketBalanceOwed_revertsWhenBorrowOwed() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 1, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_Deactivate_MarketBalanceOwed.selector);
        operator.exitMarket(address(market));
    }

    function test_unit_exitMarket_revertsWith_Operator_Deactivate_MarketBalanceOwed_revertsWhenBorrowOwedWithFirewall()
        public
    {
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 1, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_Deactivate_MarketBalanceOwed.selector);
        operator.exitMarket(address(market));
    }

    function test_unit_exitMarket_revertsWith_Operator_AssetNotFound() public {
        OperatorHarness harnessImpl = new OperatorHarness();
        bytes memory initData =
            abi.encodeWithSelector(Operator.initialize.selector, address(roles), address(blacklister), address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(address(harnessImpl), initData);
        OperatorHarness harness = OperatorHarness(address(proxy));

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), users.alice, true);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);
        harness.exitMarket(address(market));
    }

    function test_unit_exitMarket_revertsWith_Operator_AssetNotFound_variant2() public {
        OperatorHarness harness = _deployHarness();
        MockMToken otherMarket = new MockMToken();

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), users.alice, true);
        harness.setPriceOracle(address(oracleOperator));
        oracleOperator.setUnderlyingPrice(1e18);

        address[] memory assets = new address[](1);
        assets[0] = address(otherMarket);
        harness.setAccountAssets(users.alice, assets);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);
        harness.exitMarket(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                  BeforeMTokenTransfer                  //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenTransfer_revertsWith_Operator_AssetNotFound() public {
        OperatorHarness harness = _deployHarness();
        harness.setPriceOracle(address(oracleOperator));
        oracleOperator.setUnderlyingPrice(1e18);

        harness.supportMarket(address(market));
        harness.setAccountMembership(address(market), users.alice, true);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_AssetNotFound.selector);
        harness.exitMarket(address(market));

        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);
    }

    ////////////////////////////////////////////////////////////
    //                       ExitMarket                       //
    ////////////////////////////////////////////////////////////

    function test_unit_exitMarket_success_variant2() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.prank(users.alice);
        operator.exitMarket(address(market));
        assertFalse(operator.checkMembership(users.alice, address(market)));
        assertEq(operator.getAssetsIn(users.alice).length, 0);
    }

    function test_unit_exitMarket_success_variant3() public {
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.prank(users.alice);
        operator.exitMarket(address(market));
        assertEq(operator.getAssetsIn(users.alice).length, 0);
    }

    function test_unit_exitMarket_success_variant4_variant2() public {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        operator.setCollateralFactor(address(market2), 0);
        market.setSnapshot(users.alice, 10, 0, 1e18);
        market2.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(market2);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.prank(users.alice);
        operator.exitMarket(address(market));

        assertFalse(operator.checkMembership(users.alice, address(market)));
        address[] memory assets = operator.getAssetsIn(users.alice);
        assertEq(assets.length, 1);
        assertEq(assets[0], address(market2));
    }

    ////////////////////////////////////////////////////////////
    //                  BeforeMTokenTransfer                  //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenTransfer_revertsWith_Operator_Paused_revertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);
    }

    function test_unit_beforeMTokenTransfer_success() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 10);
        assertTrue(market.accrueInterestCalled());
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeRebalancing                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeRebalancing_revertsWith_Operator_Paused() public {
        _listMarket(market);
        _listMarket(market2);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), users.alice);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeRebalancing(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenRepay                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenRepay_success() public {
        _enableFirewall();
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;
        operator.setMarketBorrowCaps(markets, caps);

        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);

        market.setTotals(1, 0, 0);
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        operator.beforeMTokenMint(address(market), users.alice, users.bob);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                  BeforeMTokenTransfer                  //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenTransfer_revertsWith_Operator_UserBlacklisted_revertsWhenReceiverBlacklisted()
        public
    {
        _listMarket(market);
        blacklister.blacklist(users.bob);

        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenBorrow                   //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_Paused_revertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_MarketNotListed_revertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_SenderMustBeToken_revertsWhenSenderNotToken() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_UserNotWhitelisted_revertsWhenWhitelistEnabledAndNotWhitelisted()
        public
    {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_success_succeedsWhenWhitelistedEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 2, 0, 1e18);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 10;
        operator.setMarketBorrowCaps(markets, caps);

        market.setTotals(1, 0, 0);
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_EmptyPrice_revertsWhenPriceZero() public {
        _listMarket(market);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_MarketBorrowCapReached_revertsWhenBorrowCapReached()
        public
    {
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
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_success_succeedsWhenBorrowCapZero() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 2, 0, 1e18);
        market.setTotals(1, 0, 0);

        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_MarketBorrowSizeNotMet_revertsWhenBorrowSizeNotMet()
        public
    {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        address[] memory markets = new address[](1);
        uint256[] memory mins = new uint256[](1);
        markets[0] = address(market);
        mins[0] = 100;
        operator.setBorrowSizeMin(markets, mins);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowSizeNotMet.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 50);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_InsufficientLiquidity_revertsWhenInsufficientLiquidity()
        public
    {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 0, 1e18);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenBorrow_revertsWith_Operator_MarketNotListed_revertsForChecks() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenBorrow(address(market2), users.alice, 1);

        vm.prank(users.bob);
        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        oracleOperator.setUnderlyingPrice(0);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        oracleOperator.setUnderlyingPrice(1e18);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 5;
        operator.setMarketBorrowCaps(markets, caps);
        market.setTotals(5, 0, 0);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        caps[0] = 0;
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory mins = new uint256[](1);
        mins[0] = 10;
        operator.setBorrowSizeMin(markets, mins);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowSizeNotMet.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        mins[0] = 0;
        operator.setBorrowSizeMin(markets, mins);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 0, 1e18);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenRepay                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenRepay_revertsWith_Operator_Paused() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenBorrow(address(market2), users.alice, 1);

        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        oracleOperator.setUnderlyingPrice(0);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        oracleOperator.setUnderlyingPrice(1e18);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 10;
        operator.setMarketBorrowCaps(markets, caps);
        market.setTotals(10, 0, 0);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowCapReached.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        caps[0] = 0;
        operator.setMarketBorrowCaps(markets, caps);

        uint256[] memory mins = new uint256[](1);
        mins[0] = 10;
        operator.setBorrowSizeMin(markets, mins);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketBorrowSizeNotMet.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        mins[0] = 0;
        operator.setBorrowSizeMin(markets, mins);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 0, 1e18);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenMint(address(market2), users.alice, users.bob);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), users.alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenRepay(address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                       SetTotals                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setTotals_success_variant5() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 2, 0, 1e18);

        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 10;
        operator.setMarketBorrowCaps(markets, caps);

        market.setTotals(1, 0, 0);
        assertFalse(operator.checkMembership(users.alice, address(market)));
        vm.prank(address(market));
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenBorrow                   //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenBorrow_success_succeedsWhenAlreadyMemberAndCallerNotToken() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.prank(users.bob);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //                    BeforeMTokenMint                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenMint_revertsWith_Operator_Paused_revertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_revertsWith_Operator_MarketNotListed_revertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_revertsWith_Operator_UserNotWhitelisted_revertsWhenWhitelistEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenRepay                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenRepay_revertsWith_Operator_Paused_variant2() public {
        _listMarket(market);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenMint(address(market2), users.alice, users.bob);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), users.alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenRepay(address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                    BeforeMTokenMint                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenMint_success_succeedsWhenWhitelisted() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);

        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    function test_unit_beforeMTokenMint_success_succeeds() public {
        _listMarket(market);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                    AfterMTokenMint                     //
    ////////////////////////////////////////////////////////////

    function test_unit_afterMTokenMint_revertsWith_Operator_MarketSupplyReached_revertsWhenSupplyCapExceeded() public {
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

    function test_unit_afterMTokenMint_success_succeedsWithinSupplyCap() public {
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

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenRedeem                   //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenRedeem_success_skipsWhenNotInMarket() public {
        _listMarket(market);
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenRedeem_revertsWith_Operator_UserNotWhitelisted_revertsWhenWhitelistEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenRedeem_revertsWith_Operator_InsufficientLiquidity_revertsOnShortfall() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 10, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    function test_unit_beforeMTokenRedeem_success_succeedsWhenInMarket() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenRepay                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenRepay_revertsWith_Operator_Paused_revertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_revertsWith_Operator_MarketNotListed_revertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_revertsWith_Operator_UserNotWhitelisted_revertsWhenWhitelistEnabled() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_success_succeedsWhenWhitelisted() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);

        operator.beforeMTokenRepay(address(market), users.alice);
    }

    function test_unit_beforeMTokenRepay_success_succeeds() public {
        _listMarket(market);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                 BeforeMTokenLiquidate                  //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_RepayAmountNotValid_deprecatedRequiresFullRepay()
        public
    {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(users.alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 100);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_RepayAmountNotValid_deprecatedRepayAmountChecks()
        public
    {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(users.alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 100);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_MarketNotListed() public {
        MockMToken unlistedBorrowed = new MockMToken();
        MockMToken unlistedCollateral = new MockMToken();

        _listMarket(market);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(unlistedBorrowed), address(market), users.alice, 1);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(unlistedCollateral), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_InsufficientLiquidity_revertsWhenNoShortfall()
        public
    {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market2), 0.5e18);
        market2.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market2);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(users.alice, 10);
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_InsufficientLiquidity_revertsForShortfallAndCloseFactor()
        public
    {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market2), 0.5e18);
        market2.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market2);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(users.alice, 10);
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);

        operator.setCollateralFactor(address(market2), 0);
        market2.setSnapshot(users.alice, 0, 100, 1e18);
        market.setBorrowBalanceStored(users.alice, 100);
        operator.setCloseFactor(0.5e18);

        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 60);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_Paused() public {
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, false);

        MockMToken unlistedMarket = new MockMToken();
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(unlistedMarket), address(market2), users.alice, 1);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(unlistedMarket), users.alice, 1);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(users.alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 100);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);
        market.setReserveFactorMantissa(0);

        operator.setCollateralFactor(address(market2), 0.5e18);
        market2.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market2);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);

        operator.setCollateralFactor(address(market2), 0);
        market.setSnapshot(users.bob, 0, 100, 1e18);
        market.setBorrowBalanceStored(users.bob, 100);

        address[] memory marketsBob = new address[](1);
        marketsBob[0] = address(market);
        vm.prank(users.bob);
        operator.enterMarkets(marketsBob);

        operator.setCloseFactor(0.5e18);
        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.bob, 60);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_Paused_revertsWhenPaused() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_MarketNotListed_revertsWhenBorrowedNotListed()
        public
    {
        _listMarket(market2);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_MarketNotListed_revertsWhenCollateralNotListed()
        public
    {
        _listMarket(market);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    function test_unit_beforeMTokenLiquidate_revertsWith_Operator_RepayingTooMuch_revertsWhenRepayingTooMuch() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 100, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(users.alice, 100);
        operator.setCloseFactor(0.5e18);

        vm.expectRevert(OperatorStorage.Operator_RepayingTooMuch.selector);
        operator.beforeMTokenLiquidate(address(market), address(market), users.alice, 60);
    }

    function test_unit_beforeMTokenLiquidate_success_succeedsWithCloseFactor() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 100, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(users.alice, 100);
        operator.setCloseFactor(0.5e18);

        operator.beforeMTokenLiquidate(address(market), address(market), users.alice, 50);
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeRebalancing                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeRebalancing_success() public {
        _enableFirewall();
        _listMarket(market);
        _listMarket(market2);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 100, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        market.setBorrowBalanceStored(users.alice, 100);
        operator.setCloseFactor(0.5e18);

        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
        operator.beforeRebalancing(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenSeize                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenSeize_revertsWith_Operator_Paused_revertsWhenPaused() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_Paused_revertsWhenBorrowedPaused() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market2), ImTokenOperationTypes.OperationType.Seize, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_MarketNotListed_revertsWhenMarketNotListed() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_MarketNotListed_revertsWhenCollateralNotListed() public {
        _listMarket(market2);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    function test_unit_beforeMTokenSeize_revertsWith_Operator_Mismatch_revertsWhenOperatorsMismatch() public {
        _listMarket(market);
        _listMarket(market2);
        market.setOperator(users.bob);
        market2.setOperator(users.carol);

        vm.expectRevert(OperatorStorage.Operator_Mismatch.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeRebalancing                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeRebalancing_revertsWith_Operator_Paused_variant2() public {
        _listMarket(market);
        _listMarket(market2);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, false);

        MockMToken unlistedMarket = new MockMToken();
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(unlistedMarket), address(market2), users.alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(unlistedMarket), users.alice);

        market.setOperator(users.bob);
        market2.setOperator(users.carol);
        vm.expectRevert(OperatorStorage.Operator_Mismatch.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeRebalancing(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeMTokenSeize                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeMTokenSeize_revertsWith_Operator_MarketNotListed_variant2() public {
        MockMToken unlistedMarket = new MockMToken();

        _listMarket(market);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(unlistedMarket), users.alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(unlistedMarket), address(market), users.alice);
    }

    function test_unit_beforeMTokenSeize_success_succeeds() public {
        _listMarket(market);
        _listMarket(market2);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //            GetHypotheticalAccountLiquidity             //
    ////////////////////////////////////////////////////////////

    function test_unit_getHypotheticalAccountLiquidity_success() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        (uint256 liquidity, uint256 shortfall) = operator.getHypotheticalAccountLiquidity(users.alice, address(0), 0, 0);
        assertEq(liquidity, 0);
        assertEq(shortfall, 0);
    }

    function test_unit_getHypotheticalAccountLiquidity_revertsWith_Operator_OracleUnderlyingFetchError_revertsWhenOracleZero()
        public
    {
        _listMarket(market);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 10, 0, 1e18);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.prank(users.alice);
        operator.enterMarkets(markets);

        vm.expectRevert(OperatorStorage.Operator_OracleUnderlyingFetchError.selector);
        operator.getHypotheticalAccountLiquidity(users.alice, address(0), 0, 0);
    }

    ////////////////////////////////////////////////////////////
    //                GetUSDValueForAllMarkets                //
    ////////////////////////////////////////////////////////////

    function test_unit_getUSDValueForAllMarkets_success_skipsDeprecated() public {
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

    ////////////////////////////////////////////////////////////
    //                      IsDeprecated                      //
    ////////////////////////////////////////////////////////////

    function test_unit_isDeprecated_success_andIsMarketListed() public {
        _listMarket(market);
        assertTrue(operator.isMarketListed(address(market)));
        assertFalse(operator.isDeprecated(address(market)));

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        assertTrue(operator.isDeprecated(address(market)));
    }

    ////////////////////////////////////////////////////////////
    //                   BeforeRebalancing                    //
    ////////////////////////////////////////////////////////////

    function test_unit_beforeRebalancing_revertsWith_Operator_Paused_revertsWhenPaused() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeRebalancing(address(market));
    }

    function test_unit_beforeRebalancing_success_succeeds() public {
        _listMarket(market);
        operator.beforeRebalancing(address(market));
    }
}
