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
    //              WhitelistBlocksNonWhitelisted               //
    ////////////////////////////////////////////////////////////

    function test_unitWhitelistBlocksNonWhitelisted_success() public {
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

    ////////////////////////////////////////////////////////////
    //      WhitelistAllowsWhitelistedUserForListedMarket       //
    ////////////////////////////////////////////////////////////

    function test_unitWhitelistAllowsWhitelistedUserForListedMarket_success() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);

        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);

        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //               OnlyAllowedUserUsesWhitelist               //
    ////////////////////////////////////////////////////////////

    function test_unitOnlyAllowedUserUsesWhitelist_success() public {
        OperatorHarness harness = _deployHarness();
        harness.callOnlyAllowedUser(users.bob);

        harness.setWhitelistStatus(true);
        harness.setWhitelistedUser(users.alice, true);

        harness.callOnlyAllowedUser(users.alice);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        harness.callOnlyAllowedUser(users.bob);
    }

    ////////////////////////////////////////////////////////////
    //        WhitelistDisabledAllowsNonWhitelistedUser         //
    ////////////////////////////////////////////////////////////

    function test_unitWhitelistDisabledAllowsNonWhitelistedUser_success() public {
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
    //                 IfNotBlacklistedReverts                  //
    ////////////////////////////////////////////////////////////

    function test_unitIfNotBlacklistedReverts_revertsWith() public {
        _listMarket(market);
        blacklister.blacklist(users.alice);
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //             IfNotBlacklistedAllowsWhenClean              //
    ////////////////////////////////////////////////////////////

    function test_unitIfNotBlacklistedAllowsWhenClean_success() public {
        OperatorHarness harness = _deployHarness();
        harness.callIfNotBlacklisted(users.alice);

        blacklister.blacklist(users.alice);
        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        harness.callIfNotBlacklisted(users.alice);
    }

    ////////////////////////////////////////////////////////////
    //      BeforeMTokenMintRevertsWhenReceiverBlacklisted      //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenMintRevertsWhenReceiverBlacklisted_revertsWith() public {
        _listMarket(market);
        blacklister.blacklist(users.bob);

        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                 InitFirewallAndRegister                  //
    ////////////////////////////////////////////////////////////

    function test_unitInitFirewallAndRegister_success() public {
        MockFirewall firewall = new MockFirewall();
        operator.initFirewall(address(firewall));
        operator.firewallRegister(users.alice);

        assertEq(firewall.registerCount(), 1);
        assertEq(firewall.lastRegistered(), users.alice);
        assertFalse(firewall.lastStrictMode());
    }

    ////////////////////////////////////////////////////////////
    //                      SetBlacklister                      //
    ////////////////////////////////////////////////////////////

    function test_unitSetBlacklister_success() public {
        Blacklister blacklisterImp = new Blacklister();
        bytes memory initData = abi.encodeWithSelector(Blacklister.initialize.selector, address(this), address(roles));
        ERC1967Proxy proxy = new ERC1967Proxy(address(blacklisterImp), initData);

        operator.setBlacklister(address(proxy));
        assertEq(address(operator.blacklistOperator()), address(proxy));
    }

    ////////////////////////////////////////////////////////////
    //               SetBlacklisterRevertsOnZero                //
    ////////////////////////////////////////////////////////////

    function test_unitSetBlacklisterRevertsOnZero_revertsWith() public {
        vm.expectRevert(Operator.Operator_AddressNotValid.selector);
        operator.setBlacklister(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                           Fuzz                           //
    ////////////////////////////////////////////////////////////

    function test_unitFuzz_success_setBorrowSizeMin(uint8 len, uint256 seed, uint256 amount) public {
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

    ////////////////////////////////////////////////////////////
    //        SetBorrowSizeMinRevertsOnMismatchedLength         //
    ////////////////////////////////////////////////////////////

    function test_unitSetBorrowSizeMinRevertsOnMismatchedLength_revertsWith() public {
        address[] memory markets = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        markets[0] = address(1);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setBorrowSizeMin(markets, amounts);
    }

    ////////////////////////////////////////////////////////////
    //                SetWhitelistStatusDisables                //
    ////////////////////////////////////////////////////////////

    function test_unitSetWhitelistStatusDisables_success() public {
        operator.setWhitelistStatus(true);
        operator.setWhitelistStatus(false);
        assertFalse(operator.whitelistEnabled());
    }

    ////////////////////////////////////////////////////////////
    //                     SetRolesOperator                     //
    ////////////////////////////////////////////////////////////

    function test_unitSetRolesOperator_success() public {
        Roles newRoles = new Roles(address(this));
        operator.setRolesOperator(address(newRoles));
        assertEq(address(operator.rolesOperator()), address(newRoles));
    }

    ////////////////////////////////////////////////////////////
    //              SetRolesOperatorRevertsOnZero               //
    ////////////////////////////////////////////////////////////

    function test_unitSetRolesOperatorRevertsOnZero_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setRolesOperator(address(0));
    }

    ////////////////////////////////////////////////////////////
    //               SetPriceOracleRevertsOnZero                //
    ////////////////////////////////////////////////////////////

    function test_unitSetPriceOracleRevertsOnZero_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setPriceOracle(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                           Fuzz                           //
    ////////////////////////////////////////////////////////////

    function test_unitFuzz_success_setCloseFactor(uint256 closeFactor) public {
        closeFactor = bound(closeFactor, CLOSE_FACTOR_MIN, CLOSE_FACTOR_MAX);
        operator.setCloseFactor(closeFactor);
        assertEq(operator.closeFactorMantissa(), closeFactor);
    }

    ////////////////////////////////////////////////////////////
    //             SetCloseFactorRevertsOutOfRange              //
    ////////////////////////////////////////////////////////////

    function test_unitSetCloseFactorRevertsOutOfRange_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setCloseFactor(CLOSE_FACTOR_MIN - 1);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setCloseFactor(CLOSE_FACTOR_MAX + 1);
    }

    ////////////////////////////////////////////////////////////
    //          SetCollateralFactorRevertsForUnlisted           //
    ////////////////////////////////////////////////////////////

    function test_unitSetCollateralFactorRevertsForUnlisted_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    ////////////////////////////////////////////////////////////
    //          SetCollateralFactorRevertsForPriceZero          //
    ////////////////////////////////////////////////////////////

    function test_unitSetCollateralFactorRevertsForPriceZero_revertsWith() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(0);
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.setCollateralFactor(address(market), 0.5e18);
    }

    ////////////////////////////////////////////////////////////
    //            SetCollateralFactorRevertsAboveMax            //
    ////////////////////////////////////////////////////////////

    function test_unitSetCollateralFactorRevertsAboveMax_revertsWith() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.expectRevert(OperatorStorage.Operator_InvalidCollateralFactor.selector);
        operator.setCollateralFactor(address(market), COLLATERAL_FACTOR_MAX + 1);
    }

    ////////////////////////////////////////////////////////////
    //                SetCollateralFactorUpdates                //
    ////////////////////////////////////////////////////////////

    function test_unitSetCollateralFactorUpdates_success() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0.5e18);
        (, uint256 collateralFactor) = operator.markets(address(market));
        assertEq(collateralFactor, 0.5e18);
    }

    ////////////////////////////////////////////////////////////
    //           SupportMarketRevertsIfAlreadyListed            //
    ////////////////////////////////////////////////////////////

    function test_unitSupportMarketRevertsIfAlreadyListed_revertsWith() public {
        _listMarket(market);
        vm.expectRevert(OperatorStorage.Operator_MarketAlreadyListed.selector);
        operator.supportMarket(address(market));
    }

    ////////////////////////////////////////////////////////////
    //        SupportMarketRevertsIfAlreadyInAllMarkets         //
    ////////////////////////////////////////////////////////////

    function test_unitSupportMarketRevertsIfAlreadyInAllMarkets_revertsWith() public {
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
    //                SetOutflowVolumeTimeWindow                //
    ////////////////////////////////////////////////////////////

    function test_fuzzSetOutflowVolumeTimeWindow_success(uint256 newTimeWindow) public {
        vm.assume(newTimeWindow > 0);
        operator.setOutflowVolumeTimeWindow(newTimeWindow);
        assertEq(operator.outflowResetTimeWindow(), newTimeWindow);
    }

    ////////////////////////////////////////////////////////////
    //         SetOutflowVolumeTimeWindowRevertsOnZero          //
    ////////////////////////////////////////////////////////////

    function test_unitSetOutflowVolumeTimeWindowRevertsOnZero_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setOutflowVolumeTimeWindow(0);
    }

    ////////////////////////////////////////////////////////////
    //                    ResetOutflowVolume                    //
    ////////////////////////////////////////////////////////////

    function test_unitResetOutflowVolume_success() public {
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
    //    CheckOutflowVolumeLimitRevertsWhenMarketNotListed     //
    ////////////////////////////////////////////////////////////

    function test_unitCheckOutflowVolumeLimitRevertsWhenMarketNotListed_revertsWith() public {
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.checkOutflowVolumeLimit(1);
    }

    ////////////////////////////////////////////////////////////
    //        CheckOutflowVolumeLimitDisabledDoesNothing        //
    ////////////////////////////////////////////////////////////

    function test_unitCheckOutflowVolumeLimitDisabledDoesNothing_success() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);
        assertEq(operator.cumulativeOutflowVolume(), 0);
    }

    ////////////////////////////////////////////////////////////
    //      CheckOutflowVolumeLimitResetsWindowAndUpdates       //
    ////////////////////////////////////////////////////////////

    function test_unitCheckOutflowVolumeLimitResetsWindowAndUpdates_success() public {
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

    ////////////////////////////////////////////////////////////
    //     CheckOutflowVolumeLimitDoesNotResetWithinWindow      //
    ////////////////////////////////////////////////////////////

    function test_unitCheckOutflowVolumeLimitDoesNotResetWithinWindow_success() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(10);

        uint256 lastReset = operator.lastOutflowResetTimestamp();
        vm.prank(address(market));
        operator.checkOutflowVolumeLimit(1e10);

        assertEq(operator.lastOutflowResetTimestamp(), lastReset);
        assertEq(operator.cumulativeOutflowVolume(), 1);
    }

    ////////////////////////////////////////////////////////////
    //       CheckOutflowVolumeLimitRevertsWhenOverLimit        //
    ////////////////////////////////////////////////////////////

    function test_unitCheckOutflowVolumeLimitRevertsWhenOverLimit_revertsWith() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setOutflowTimeLimitInUSD(1);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_OutflowVolumeReached.selector);
        operator.checkOutflowVolumeLimit(2e10);
    }

    ////////////////////////////////////////////////////////////
    //       CheckOutflowVolumeLimitRevertsWhenOracleZero       //
    ////////////////////////////////////////////////////////////

    function test_unitCheckOutflowVolumeLimitRevertsWhenOracleZero_revertsWith() public {
        _listMarket(market);
        operator.setOutflowTimeLimitInUSD(1);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_OracleUnderlyingFetchError.selector);
        operator.checkOutflowVolumeLimit(1);
    }

    ////////////////////////////////////////////////////////////
    //               SetMarketBorrowCapsGuardian                //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketBorrowCapsGuardian_success() public {
        roles.allowFor(guardian, roles.GUARDIAN_BORROW_CAP(), true);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(guardian);
        operator.setMarketBorrowCaps(markets, caps);
        assertEq(operator.borrowCaps(address(market)), 100);
    }

    ////////////////////////////////////////////////////////////
    //                 SetMarketBorrowCapsOwner                 //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketBorrowCapsOwner_success() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 55;

        operator.setMarketBorrowCaps(markets, caps);
        assertEq(operator.borrowCaps(address(market)), 55);
    }

    ////////////////////////////////////////////////////////////
    //         SetMarketBorrowCapsRevertsForNonGuardian         //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketBorrowCapsRevertsForNonGuardian_revertsWith() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //         SetMarketBorrowCapsRevertsOnInvalidInput         //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketBorrowCapsRevertsOnInvalidInput_revertsWith() public {
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);
        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //      SetMarketBorrowCapsRevertsOnMismatchedLengths       //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketBorrowCapsRevertsOnMismatchedLengths_revertsWith() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](2);
        markets[0] = address(market);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketBorrowCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //               SetMarketSupplyCapsGuardian                //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketSupplyCapsGuardian_success() public {
        roles.allowFor(guardian, roles.GUARDIAN_SUPPLY_CAP(), true);
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(guardian);
        operator.setMarketSupplyCaps(markets, caps);
        assertEq(operator.supplyCaps(address(market)), 100);
    }

    ////////////////////////////////////////////////////////////
    //                 SetMarketSupplyCapsOwner                 //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketSupplyCapsOwner_success() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 77;

        operator.setMarketSupplyCaps(markets, caps);
        assertEq(operator.supplyCaps(address(market)), 77);
    }

    ////////////////////////////////////////////////////////////
    //         SetMarketSupplyCapsRevertsForNonGuardian         //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketSupplyCapsRevertsForNonGuardian_revertsWith() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](1);
        markets[0] = address(market);
        caps[0] = 100;

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //         SetMarketSupplyCapsRevertsOnInvalidInput         //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketSupplyCapsRevertsOnInvalidInput_revertsWith() public {
        address[] memory markets = new address[](1);
        uint256[] memory caps = new uint256[](0);
        markets[0] = address(market);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //         SetMarketSupplyCapsRevertsOnEmptyArrays          //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketSupplyCapsRevertsOnEmptyArrays_revertsWith() public {
        address[] memory markets = new address[](0);
        uint256[] memory caps = new uint256[](0);

        vm.expectRevert(OperatorStorage.Operator_InvalidInput.selector);
        operator.setMarketSupplyCaps(markets, caps);
    }

    ////////////////////////////////////////////////////////////
    //   SetMarketCapsRevertsForUnauthorizedAndInvalidInputs    //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketCapsRevertsForUnauthorizedAndInvalidInputs_revertsWith() public {
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
    //                 CapsAndPauseGuardsRevert                 //
    ////////////////////////////////////////////////////////////

    function test_unitCapsAndPauseGuardsRevert_revertsWith() public {
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
    //          AdminActionsSucceedWithFirewallEnabled          //
    ////////////////////////////////////////////////////////////

    function test_unitAdminActionsSucceedWithFirewallEnabled_success() public {
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
    //          SetPausedGuardianCanPauseOwnerUnpauses          //
    ////////////////////////////////////////////////////////////

    function test_unitSetPausedGuardianCanPauseOwnerUnpauses_success() public {
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

    ////////////////////////////////////////////////////////////
    //          SetPausedRevertsWhenPausingWithoutRole          //
    ////////////////////////////////////////////////////////////

    function test_unitSetPausedRevertsWhenPausingWithoutRole_revertsWith() public {
        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
    }

    ////////////////////////////////////////////////////////////
    //      SetPausedRevertsForUnauthorizedPauseAndUnpause      //
    ////////////////////////////////////////////////////////////

    function test_unitSetPausedRevertsForUnauthorizedPauseAndUnpause_revertsWith() public {
        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdminOrRole.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_OnlyAdmin.selector);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, false);
    }

    ////////////////////////////////////////////////////////////
    //                  SetPausedOwnerCanPause                  //
    ////////////////////////////////////////////////////////////

    function test_unitSetPausedOwnerCanPause_success() public {
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        assertTrue(operator.isPaused(address(market), ImTokenOperationTypes.OperationType.Borrow));
    }

    ////////////////////////////////////////////////////////////
    //             InitializeRevertsOnInvalidInputs             //
    ////////////////////////////////////////////////////////////

    function test_unitInitializeRevertsOnInvalidInputs_revertsWith() public {
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
    //           EnterMarketsWithSenderRequiresListed           //
    ////////////////////////////////////////////////////////////

    function test_unitEnterMarketsWithSenderRequiresListed_success() public {
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.enterMarketsWithSender(users.alice);
    }

    ////////////////////////////////////////////////////////////
    //           EnterMarketsWithSenderAddsMembership           //
    ////////////////////////////////////////////////////////////

    function test_unitEnterMarketsWithSenderAddsMembership_success() public {
        _listMarket(market);
        vm.prank(address(market));
        operator.enterMarketsWithSender(users.alice);
        assertTrue(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //    EnterMarketsWithSenderRevertsWhenWhitelistEnabled     //
    ////////////////////////////////////////////////////////////

    function test_unitEnterMarketsWithSenderRevertsWhenWhitelistEnabled_revertsWith() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.enterMarketsWithSender(users.alice);
    }

    ////////////////////////////////////////////////////////////
    //          EnterMarketsRevertsWhenMarketNotListed          //
    ////////////////////////////////////////////////////////////

    function test_unitEnterMarketsRevertsWhenMarketNotListed_revertsWith() public {
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.prank(users.alice);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.enterMarkets(markets);
    }

    ////////////////////////////////////////////////////////////
    //           EnterMarketsAddsAssetAndGetAssetsIn            //
    ////////////////////////////////////////////////////////////

    function test_unitEnterMarketsAddsAssetAndGetAssetsIn_success() public {
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
    //                 GetAllMarketsReturnsList                 //
    ////////////////////////////////////////////////////////////

    function test_unitGetAllMarketsReturnsList_success() public {
        _listMarket(market);
        _listMarket(market2);

        address[] memory markets = operator.getAllMarkets();
        assertEq(markets.length, 2);
        assertEq(markets[0], address(market));
        assertEq(markets[1], address(market2));
    }

    ////////////////////////////////////////////////////////////
    //              ExitMarketReturnsWhenNotMember              //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketReturnsWhenNotMember_success() public {
        _listMarket(market);
        vm.prank(users.alice);
        operator.exitMarket(address(market));
        assertFalse(operator.checkMembership(users.alice, address(market)));
    }

    ////////////////////////////////////////////////////////////
    //             ExitMarketRevertsWhenBorrowOwed              //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketRevertsWhenBorrowOwed_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //       ExitMarketRevertsWhenBorrowOwedWithFirewall        //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketRevertsWhenBorrowOwedWithFirewall_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //            ExitMarketRevertsWhenAssetNotFound            //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketRevertsWhenAssetNotFound_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //   ExitMarketRevertsWhenAssetNotFoundWithNonEmptyAssets   //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketRevertsWhenAssetNotFoundWithNonEmptyAssets_revertsWith() public {
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
    //    ExitMarketRevertsWhenAssetMissingAndTransferPaused    //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketRevertsWhenAssetMissingAndTransferPaused_revertsWith() public {
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
    //                  ExitMarketRemovesAsset                  //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketRemovesAsset_success() public {
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

    ////////////////////////////////////////////////////////////
    //        EnterExitMarketsSucceedWithFirewallEnabled        //
    ////////////////////////////////////////////////////////////

    function test_unitEnterExitMarketsSucceedWithFirewallEnabled_success() public {
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

    ////////////////////////////////////////////////////////////
    //               ExitMarketRemovesMiddleAsset               //
    ////////////////////////////////////////////////////////////

    function test_unitExitMarketRemovesMiddleAsset_success() public {
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
    //          BeforeMTokenTransferRevertsWhenPaused           //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenTransferRevertsWhenPaused_revertsWith() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Transfer, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);
    }

    ////////////////////////////////////////////////////////////
    //           BeforeMTokenTransferAccruesInterest            //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenTransferAccruesInterest_success() public {
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
    //                BeforeOpsRevertWhenPaused                 //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeOpsRevertWhenPaused_revertsWith() public {
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
    //           BeforeOpsSucceedWithFirewallEnabled            //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeOpsSucceedWithFirewallEnabled_success() public {
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
    //    BeforeMTokenTransferRevertsWhenReceiverBlacklisted    //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenTransferRevertsWhenReceiverBlacklisted_revertsWith() public {
        _listMarket(market);
        blacklister.blacklist(users.bob);

        vm.expectRevert(OperatorStorage.Operator_UserBlacklisted.selector);
        operator.beforeMTokenTransfer(address(market), users.alice, users.bob, 1);
    }

    ////////////////////////////////////////////////////////////
    //           BeforeMTokenBorrowRevertsWhenPaused            //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenPaused_revertsWith() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenBorrowRevertsWhenMarketNotListed       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenMarketNotListed_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenBorrowRevertsWhenSenderNotToken        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenSenderNotToken_revertsWith() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        vm.expectRevert(OperatorStorage.Operator_SenderMustBeToken.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //BeforeMTokenBorrowRevertsWhenWhitelistEnabledAndNotWhitelisted//
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenWhitelistEnabledAndNotWhitelisted_revertsWith() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //     BeforeMTokenBorrowSucceedsWhenWhitelistedEnabled     //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowSucceedsWhenWhitelistedEnabled_success() public {
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

    ////////////////////////////////////////////////////////////
    //          BeforeMTokenBorrowRevertsWhenPriceZero          //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenPriceZero_revertsWith() public {
        _listMarket(market);
        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_EmptyPrice.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //      BeforeMTokenBorrowRevertsWhenBorrowCapReached       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenBorrowCapReached_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenBorrowSucceedsWhenBorrowCapZero        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowSucceedsWhenBorrowCapZero_success() public {
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

    ////////////////////////////////////////////////////////////
    //      BeforeMTokenBorrowRevertsWhenBorrowSizeNotMet       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenBorrowSizeNotMet_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //    BeforeMTokenBorrowRevertsWhenInsufficientLiquidity    //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsWhenInsufficientLiquidity_revertsWith() public {
        _listMarket(market);
        oracleOperator.setUnderlyingPrice(1e18);
        operator.setCollateralFactor(address(market), 0);
        market.setSnapshot(users.alice, 0, 0, 1e18);

        vm.prank(address(market));
        vm.expectRevert(OperatorStorage.Operator_InsufficientLiquidity.selector);
        operator.beforeMTokenBorrow(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //            BeforeMTokenBorrowRevertsForChecks            //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowRevertsForChecks_revertsWith() public {
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
    //     BeforeMTokenBorrowMintRepayRevertsForGuardChecks     //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowMintRepayRevertsForGuardChecks_revertsWith() public {
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
    //                BeforeMTokenBorrowSucceeds                //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowSucceeds_success() public {
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
    //BeforeMTokenBorrowSucceedsWhenAlreadyMemberAndCallerNotToken//
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenBorrowSucceedsWhenAlreadyMemberAndCallerNotToken_success() public {
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
    //            BeforeMTokenMintRevertsWhenPaused             //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenMintRevertsWhenPaused_revertsWith() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Mint, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //        BeforeMTokenMintRevertsWhenMarketNotListed        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenMintRevertsWhenMarketNotListed_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenMintRevertsWhenWhitelistEnabled        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenMintRevertsWhenWhitelistEnabled_revertsWith() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //           BeforeMTokenMintAndRepayRevertChecks           //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenMintAndRepayRevertChecks_revertsWith() public {
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
    //         BeforeMTokenMintSucceedsWhenWhitelisted          //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenMintSucceedsWhenWhitelisted_success() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);

        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //                 BeforeMTokenMintSucceeds                 //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenMintSucceeds_success() public {
        _listMarket(market);
        operator.beforeMTokenMint(address(market), users.alice, users.bob);
    }

    ////////////////////////////////////////////////////////////
    //       AfterMTokenMintRevertsWhenSupplyCapExceeded        //
    ////////////////////////////////////////////////////////////

    function test_unitAfterMTokenMintRevertsWhenSupplyCapExceeded_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //          AfterMTokenMintSucceedsWithinSupplyCap          //
    ////////////////////////////////////////////////////////////

    function test_unitAfterMTokenMintSucceedsWithinSupplyCap_success() public {
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
    //          BeforeMTokenRedeemSkipsWhenNotInMarket          //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRedeemSkipsWhenNotInMarket_success() public {
        _listMarket(market);
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //      BeforeMTokenRedeemRevertsWhenWhitelistEnabled       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRedeemRevertsWhenWhitelistEnabled_revertsWith() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenRedeem(address(market), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //           BeforeMTokenRedeemRevertsOnShortfall           //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRedeemRevertsOnShortfall_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //          BeforeMTokenRedeemSucceedsWhenInMarket          //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRedeemSucceedsWhenInMarket_success() public {
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
    //            BeforeMTokenRepayRevertsWhenPaused            //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRepayRevertsWhenPaused_revertsWith() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Repay, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenRepayRevertsWhenMarketNotListed        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRepayRevertsWhenMarketNotListed_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenRepayRevertsWhenWhitelistEnabled       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRepayRevertsWhenWhitelistEnabled_revertsWith() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);

        vm.expectRevert(OperatorStorage.Operator_UserNotWhitelisted.selector);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //         BeforeMTokenRepaySucceedsWhenWhitelisted         //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRepaySucceedsWhenWhitelisted_success() public {
        _listMarket(market);
        operator.setWhitelistStatus(true);
        operator.setWhitelistedUser(users.alice, true);

        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                BeforeMTokenRepaySucceeds                 //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenRepaySucceeds_success() public {
        _listMarket(market);
        operator.beforeMTokenRepay(address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //     BeforeMTokenLiquidateDeprecatedRequiresFullRepay     //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateDeprecatedRequiresFullRepay_success() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(users.alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 100);
    }

    ////////////////////////////////////////////////////////////
    //     BeforeMTokenLiquidateDeprecatedRepayAmountChecks     //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateDeprecatedRepayAmountChecks_success() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        market.setBorrowBalanceStored(users.alice, 100);

        vm.expectRevert(OperatorStorage.Operator_RepayAmountNotValid.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 50);

        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 100);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenLiquidateRevertsForListingChecks       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsForListingChecks_revertsWith() public {
        MockMToken unlistedBorrowed = new MockMToken();
        MockMToken unlistedCollateral = new MockMToken();

        _listMarket(market);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(unlistedBorrowed), address(market), users.alice, 1);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(unlistedCollateral), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenLiquidateRevertsWhenNoShortfall        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsWhenNoShortfall_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //  BeforeMTokenLiquidateRevertsForShortfallAndCloseFactor  //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsForShortfallAndCloseFactor_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //BeforeMTokenLiquidateRevertsForDeprecatedAndShortfallChecks//
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsForDeprecatedAndShortfallChecks_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //          BeforeMTokenLiquidateRevertsWhenPaused          //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsWhenPaused_revertsWith() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Liquidate, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //    BeforeMTokenLiquidateRevertsWhenBorrowedNotListed     //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsWhenBorrowedNotListed_revertsWith() public {
        _listMarket(market2);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //   BeforeMTokenLiquidateRevertsWhenCollateralNotListed    //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsWhenCollateralNotListed_revertsWith() public {
        _listMarket(market);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenLiquidate(address(market), address(market2), users.alice, 1);
    }

    ////////////////////////////////////////////////////////////
    //     BeforeMTokenLiquidateRevertsWhenRepayingTooMuch      //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateRevertsWhenRepayingTooMuch_revertsWith() public {
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

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenLiquidateSucceedsWithCloseFactor       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenLiquidateSucceedsWithCloseFactor_success() public {
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
    //   LiquidationSeizeRebalanceSucceedWithFirewallEnabled    //
    ////////////////////////////////////////////////////////////

    function test_unitLiquidationSeizeRebalanceSucceedWithFirewallEnabled_success() public {
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
    //            BeforeMTokenSeizeRevertsWhenPaused            //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeRevertsWhenPaused_revertsWith() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Seize, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //        BeforeMTokenSeizeRevertsWhenBorrowedPaused        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeRevertsWhenBorrowedPaused_revertsWith() public {
        _listMarket(market);
        _listMarket(market2);
        operator.setPaused(address(market2), ImTokenOperationTypes.OperationType.Seize, true);

        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //       BeforeMTokenSeizeRevertsWhenMarketNotListed        //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeRevertsWhenMarketNotListed_revertsWith() public {
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //     BeforeMTokenSeizeRevertsWhenCollateralNotListed      //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeRevertsWhenCollateralNotListed_revertsWith() public {
        _listMarket(market2);
        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //      BeforeMTokenSeizeRevertsWhenOperatorsMismatch       //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeRevertsWhenOperatorsMismatch_revertsWith() public {
        _listMarket(market);
        _listMarket(market2);
        market.setOperator(users.bob);
        market2.setOperator(users.carol);

        vm.expectRevert(OperatorStorage.Operator_Mismatch.selector);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //    BeforeMTokenSeizeRevertsForPauseListingAndMismatch    //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeRevertsForPauseListingAndMismatch_revertsWith() public {
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
    //         BeforeMTokenSeizeRevertsForListingChecks         //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeRevertsForListingChecks_revertsWith() public {
        MockMToken unlistedMarket = new MockMToken();

        _listMarket(market);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(market), address(unlistedMarket), users.alice);

        vm.expectRevert(OperatorStorage.Operator_MarketNotListed.selector);
        operator.beforeMTokenSeize(address(unlistedMarket), address(market), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //                BeforeMTokenSeizeSucceeds                 //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeMTokenSeizeSucceeds_success() public {
        _listMarket(market);
        _listMarket(market2);
        operator.beforeMTokenSeize(address(market), address(market2), users.alice);
    }

    ////////////////////////////////////////////////////////////
    //             GetHypotheticalAccountLiquidity              //
    ////////////////////////////////////////////////////////////

    function test_unitGetHypotheticalAccountLiquidity_success() public {
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

    ////////////////////////////////////////////////////////////
    //   GetHypotheticalAccountLiquidityRevertsWhenOracleZero   //
    ////////////////////////////////////////////////////////////

    function test_unitGetHypotheticalAccountLiquidityRevertsWhenOracleZero_revertsWith() public {
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
    //         GetUSDValueForAllMarketsSkipsDeprecated          //
    ////////////////////////////////////////////////////////////

    function test_unitGetUSDValueForAllMarketsSkipsDeprecated_success() public {
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
    //              IsDeprecatedAndIsMarketListed               //
    ////////////////////////////////////////////////////////////

    function test_unitIsDeprecatedAndIsMarketListed_success() public {
        _listMarket(market);
        assertTrue(operator.isMarketListed(address(market)));
        assertFalse(operator.isDeprecated(address(market)));

        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Borrow, true);
        market.setReserveFactorMantissa(1e18);
        assertTrue(operator.isDeprecated(address(market)));
    }

    ////////////////////////////////////////////////////////////
    //            BeforeRebalancingRevertsWhenPaused            //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeRebalancingRevertsWhenPaused_revertsWith() public {
        _listMarket(market);
        operator.setPaused(address(market), ImTokenOperationTypes.OperationType.Rebalancing, true);
        vm.expectRevert(OperatorStorage.Operator_Paused.selector);
        operator.beforeRebalancing(address(market));
    }

    ////////////////////////////////////////////////////////////
    //                BeforeRebalancingSucceeds                 //
    ////////////////////////////////////////////////////////////

    function test_unitBeforeRebalancingSucceeds_success() public {
        _listMarket(market);
        operator.beforeRebalancing(address(market));
    }
}
