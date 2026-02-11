// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IRebalancer} from "src/interfaces/IRebalancer.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {BaseRebalancerTest} from "test/utils/BaseRebalancerTest.t.sol";
import {
    MockFirewallRegister,
    MockRebalanceMarket,
    RejectEthReceiver
} from "test/mocks/rebalancer/RebalancerMocks.t.sol";

contract RebalancerTest is BaseRebalancerTest {
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);

    MockRebalanceMarket internal market;

    function setUp() public override {
        super.setUp();

        market = new MockRebalanceMarket(address(weth));

        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        rebalancer.setMaxTransferSize(0, address(weth), type(uint256).max);
        rebalancer.setMaxTransferSize(MAINNET_CHAIN_ID, address(weth), type(uint256).max);
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), false);
    }

    modifier givenSenderHasRole(bytes32 role) {
        roles.allowFor(address(this), role, true);
        _;
    }

    ////////////////////////////////////////////////////////////
    //                        SaveEth                         //
    ////////////////////////////////////////////////////////////

    function test_unit_saveEth_revertsWith_Rebalancer_NotAuthorized_whenFirewallEnabled() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setMarketStatus(markets, true);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setAllowList(markets, true);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedDestination(MAINNET_CHAIN_ID, true);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setMinTransferSize(MAINNET_CHAIN_ID, address(weth), 1);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setMaxTransferSize(MAINNET_CHAIN_ID, address(weth), 1);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.saveEth();
    }

    function test_unit_saveEth_revertsWith_Rebalancer_RequestNotValid_whenFirewallRejects() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        RejectEthReceiver rejector = new RejectEthReceiver();
        Rebalancer localRebalancer = new Rebalancer(address(roles), address(rejector), address(this), "");
        MockFirewall firewall = new MockFirewall();
        vm.store(address(localRebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));
        localRebalancer.setFirewall(address(firewall));
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.deal(address(localRebalancer), 1 ether);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        localRebalancer.saveEth();
    }

    function test_unit_saveEth_revertsWith_Rebalancer_NotAuthorized_whenCallerNotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.saveEth();
    }

    function test_unit_saveEth_revertsWith_Rebalancer_RequestNotValid_whenReceiverRejects() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        RejectEthReceiver rejector = new RejectEthReceiver();
        Rebalancer localRebalancer = new Rebalancer(address(roles), address(rejector), address(this), "");

        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.deal(address(localRebalancer), 1 ether);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        localRebalancer.saveEth();
    }

    function test_unit_saveEth_success_withFirewallEnabled() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amountToSave = 1 ether;
        Rebalancer localRebalancer = new Rebalancer(address(roles), users.alice, address(this), "");
        MockFirewall firewall = new MockFirewall();
        vm.store(address(localRebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));
        localRebalancer.setFirewall(address(firewall));
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.deal(address(localRebalancer), amountToSave);

        uint256 balanceBefore = users.alice.balance;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IRebalancer.EthSaved(amountToSave);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        localRebalancer.saveEth();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            users.alice.balance,
            balanceBefore + amountToSave,
            "expected users.alice.balance to equal balanceBefore + amountToSave"
        );
        assertEq(
            address(localRebalancer).balance, 0, "expected address(localRebalancer).balance to equal 0 after saveEth()"
        );
    }

    function test_unit_saveEth_success_transfersToSaveAddress() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amountToSave = 1 ether;
        Rebalancer localRebalancer = new Rebalancer(address(roles), users.alice, address(this), "");

        _allowGuardian();
        vm.deal(address(localRebalancer), amountToSave);

        uint256 aliceBalanceBefore = users.alice.balance;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IRebalancer.EthSaved(amountToSave);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        localRebalancer.saveEth();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            users.alice.balance,
            aliceBalanceBefore + amountToSave,
            "expected users.alice.balance to equal aliceBalanceBefore + amountToSave"
        );
        assertEq(
            address(localRebalancer).balance, 0, "expected address(localRebalancer).balance to equal 0 after saveEth()"
        );
    }

    ////////////////////////////////////////////////////////////
    //               SetWhitelistedBridgeStatus               //
    ////////////////////////////////////////////////////////////

    function test_unit_setWhitelistedBridgeStatus_revertsWith_Rebalancer_AddressNotValid_whenFirewallEnabled()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();
        _allowGuardian();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(0), true);
    }

    function test_unit_setWhitelistedBridgeStatus_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
    }

    function test_unit_setWhitelistedBridgeStatus_revertsWith_Rebalancer_AddressNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(0), true);
    }

    function test_unit_setWhitelistedBridgeStatus_revertsWith_Rebalancer_NotAuthorized_whenSetWhitelistedBridgeStatusIsCalledWithTrue()
        external
        givenSenderDoesNotHaveGUARDIAN_BRIDGERole
    {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        // it should not set a bridge and revert with Rebalancer_NotAuthorized
    }

    function test_unit_setWhitelistedBridgeStatus_revertsWith_Rebalancer_NotAuthorized_whenSetWhitelistedBridgeStatusIsCalledWithFalse()
        external
        givenSenderDoesNotHaveGUARDIAN_BRIDGERole
    {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), false);
    }

    function test_unit_setWhitelistedBridgeStatus_success_withFirewallEnabled()
        external
        givenSenderHasRole(roles.GUARDIAN_BRIDGE())
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.BridgeWhitelistedStatusUpdated(address(bridgeMock), true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.isBridgeWhitelisted(address(bridgeMock)),
            "expected condition to be true: rebalancer.isBridgeWhitelisted(address(bridgeMock))"
        );
    }

    function test_unit_setWhitelistedBridgeStatus_success() external givenSenderHasRole(roles.GUARDIAN_BRIDGE()) {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.BridgeWhitelistedStatusUpdated(address(bridgeMock), true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.isBridgeWhitelisted(address(bridgeMock)),
            "expected condition to be true: rebalancer.isBridgeWhitelisted(address(bridgeMock))"
        );

        vm.expectEmit(true, true, true, true);
        emit IRebalancer.BridgeWhitelistedStatusUpdated(address(bridgeMock), false);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), false);
        assertFalse(
            rebalancer.isBridgeWhitelisted(address(bridgeMock)),
            "expected condition to be false: rebalancer.isBridgeWhitelisted(address(bridgeMock))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    SetAllowedTokens                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setAllowedTokens_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
    }

    function test_unit_setAllowedTokens_success_updatesMapping() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IRebalancer.AllowedTokensUpdated(address(bridgeMock), true, tokens);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)),
            "expected condition to be true: rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth))"
        );
        assertTrue(
            rebalancer.allowedTokensPerBridge(address(bridgeMock), address(usdc)),
            "expected condition to be true: rebalancer.allowedTokensPerBridge(address(bridgeMock), address(usdc))"
        );
    }

    function test_unit_setAllowedTokens_success_removesMapping() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IRebalancer.AllowedTokensUpdated(address(bridgeMock), true, tokens);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)),
            "expected condition to be true: rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth))"
        );

        vm.expectEmit(true, false, false, true);
        emit IRebalancer.AllowedTokensUpdated(address(bridgeMock), false, tokens);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, false);
        assertFalse(
            rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)),
            "expected condition to be false: rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    SetMarketStatus                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketStatus_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMarketStatus(markets, true);
    }

    function test_unit_setMarketStatus_success_updatesMapping() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IRebalancer.MarketListUpdated(markets, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMarketStatus(markets, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.whitelistedMarkets(address(market)),
            "expected condition to be true: rebalancer.whitelistedMarkets(address(market))"
        );
        assertTrue(
            rebalancer.whitelistedMarkets(address(mWethHost)),
            "expected condition to be true: rebalancer.whitelistedMarkets(address(mWethHost))"
        );
    }

    function test_unit_setMarketStatus_success() external givenSenderHasRole(roles.GUARDIAN_BRIDGE()) {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        markets[0] = address(mWethHost);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IRebalancer.MarketListUpdated(markets, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMarketStatus(markets, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.isMarketWhitelisted(address(mWethHost)),
            "expected condition to be true: rebalancer.isMarketWhitelisted(address(mWethHost))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      SetAllowList                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setAllowList_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(false, false, false, true);
        emit IRebalancer.AllowedListUpdated(markets, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAllowList(markets, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.allowedList(address(market)),
            "expected condition to be true: rebalancer.allowedList(address(market))"
        );
    }

    function test_unit_setAllowList_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAllowList(markets, true);
    }

    ////////////////////////////////////////////////////////////
    //               SetWhitelistedDestination                //
    ////////////////////////////////////////////////////////////

    function test_unit_setWhitelistedDestination_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IRebalancer.DestinationWhitelistedStatusUpdated(OPTIMISM_CHAIN_ID, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedDestination(OPTIMISM_CHAIN_ID, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.isDestinationWhitelisted(10),
            "expected condition to be true: rebalancer.isDestinationWhitelisted(10)"
        );
    }

    function test_unit_setWhitelistedDestination_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedDestination(OPTIMISM_CHAIN_ID, true);
    }

    ////////////////////////////////////////////////////////////
    //                   SetMinTransferSize                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMinTransferSize_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = 5;
        uint256 minTransferSize = 123;
        _allowGuardian();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IRebalancer.MinTransferSizeUpdated(destinationChainId, address(weth), minTransferSize);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMinTransferSize(destinationChainId, address(weth), minTransferSize);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.minTransferSizes(destinationChainId, address(weth)),
            minTransferSize,
            "expected rebalancer.minTransferSizes(destinationChainId, address(weth)) to equal minTransferSize"
        );
    }

    function test_fuzz_setMinTransferSize_success(uint32 destinationChainIdRaw, uint256 minTransferSizeRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = uint32(bound(destinationChainIdRaw, 1, type(uint32).max));
        uint256 minTransferSize = bound(minTransferSizeRaw, 0, type(uint128).max);

        _allowGuardian();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IRebalancer.MinTransferSizeUpdated(destinationChainId, address(weth), minTransferSize);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMinTransferSize(destinationChainId, address(weth), minTransferSize);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.minTransferSizes(destinationChainId, address(weth)),
            minTransferSize,
            "expected rebalancer.minTransferSizes(destinationChainId, address(weth)) to equal minTransferSize"
        );
    }

    function test_unit_setMinTransferSize_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMinTransferSize(5, address(weth), 123);
    }

    ////////////////////////////////////////////////////////////
    //                   SetMaxTransferSize                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMaxTransferSize_success_withFirewallEnabled() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = MAINNET_CHAIN_ID;
        uint256 minTransferSize = 1;
        uint256 maxTransferSize = 2;
        _enableFirewall();
        _allowGuardian();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        rebalancer.setMarketStatus(markets, true);
        rebalancer.setAllowList(markets, true);

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(destinationChainId, true);
        rebalancer.setMinTransferSize(destinationChainId, address(weth), minTransferSize);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IRebalancer.MaxTransferSizeUpdated(destinationChainId, address(weth), maxTransferSize);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMaxTransferSize(destinationChainId, address(weth), maxTransferSize);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.maxTransferSizes(destinationChainId, address(weth)),
            maxTransferSize,
            "expected rebalancer.maxTransferSizes(destinationChainId, address(weth)) to equal maxTransferSize"
        );
    }

    function test_unit_setMaxTransferSize_revertsWith_Rebalancer_NotAuthorized_whenFirewallEnabledAndCallerHasNoGuardianRole()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();
        uint32 destinationChainId = MAINNET_CHAIN_ID;
        uint256 maxTransferSize = 2;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMaxTransferSize(destinationChainId, address(weth), maxTransferSize);
    }

    function test_unit_setMaxTransferSize_success_updatesMapping() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = 6;
        uint256 maxTransferSize = 456;
        _allowGuardian();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IRebalancer.MaxTransferSizeUpdated(destinationChainId, address(weth), maxTransferSize);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMaxTransferSize(destinationChainId, address(weth), maxTransferSize);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.maxTransferSizes(destinationChainId, address(weth)),
            maxTransferSize,
            "expected rebalancer.maxTransferSizes(destinationChainId, address(weth)) to equal maxTransferSize"
        );
    }

    function test_fuzz_setMaxTransferSize_success_updatesMapping(
        uint32 destinationChainIdRaw,
        uint256 maxTransferSizeRaw
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = uint32(bound(destinationChainIdRaw, 1, type(uint32).max));
        uint256 maxTransferSize = bound(maxTransferSizeRaw, 0, type(uint128).max);

        _allowGuardian();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IRebalancer.MaxTransferSizeUpdated(destinationChainId, address(weth), maxTransferSize);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMaxTransferSize(destinationChainId, address(weth), maxTransferSize);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.maxTransferSizes(destinationChainId, address(weth)),
            maxTransferSize,
            "expected rebalancer.maxTransferSizes(destinationChainId, address(weth)) to equal maxTransferSize"
        );
    }

    function test_unit_setMaxTransferSize_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMaxTransferSize(6, address(weth), 456);
    }

    ////////////////////////////////////////////////////////////
    //                        SetAdmin                        //
    ////////////////////////////////////////////////////////////

    function test_unit_setAdmin_success() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IRebalancer.NewAdmin(users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAdmin(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rebalancer.admin(), users.alice, "expected rebalancer.admin() to equal users.alice");
    }

    function test_unit_setAdmin_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        rebalancer.setAdmin(users.bob);
    }

    function test_unit_setAdmin_revertsWith_Rebalancer_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAdmin(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                     SetSaveAddress                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setSaveAddress_success() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit IRebalancer.SaveAddressUpdated(users.alice);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setSaveAddress(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rebalancer.saveAddress(), users.alice, "expected rebalancer.saveAddress() to equal users.alice");
    }

    function test_unit_setSaveAddress_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        rebalancer.setSaveAddress(users.bob);
    }

    function test_unit_setSaveAddress_revertsWith_Rebalancer_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setSaveAddress(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                       SaveTokens                       //
    ////////////////////////////////////////////////////////////

    function test_unit_saveTokens_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        rebalancer.saveTokens(address(weth), address(market));
    }

    function test_unit_saveTokens_revertsWith_Rebalancer_RequestNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockRebalanceMarket otherMarket = new MockRebalanceMarket(address(usdc));
        _getTokens(weth, address(rebalancer), 1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.saveTokens(address(weth), address(otherMarket));
    }

    function test_unit_saveTokens_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amountToSave = 2e18;
        _getTokens(weth, address(rebalancer), amountToSave);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit IRebalancer.TokensSaved(address(weth), address(market), amountToSave);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.saveTokens(address(weth), address(market));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            weth.balanceOf(address(market)),
            amountToSave,
            "expected weth.balanceOf(address(market)) to equal amountToSave"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_Rebalancer_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new Rebalancer(address(0), address(this), address(this), "");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new Rebalancer(address(roles), address(0), address(this), "");

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new Rebalancer(address(roles), address(this), address(0), "");
    }

    function test_unit_constructor_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address saveAddress = users.alice;
        address localAdmin = users.bob;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        Rebalancer localRebalancer = new Rebalancer(address(roles), saveAddress, localAdmin, "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(localRebalancer.roles()),
            address(roles),
            "expected address(localRebalancer.roles()) to equal address(roles)"
        );
        assertEq(
            localRebalancer.saveAddress(), saveAddress, "expected localRebalancer.saveAddress() to equal saveAddress"
        );
        assertEq(localRebalancer.admin(), localAdmin, "expected localRebalancer.admin() to equal localAdmin");
        assertEq(
            localRebalancer.transferTimeWindow(), 86400, "expected localRebalancer.transferTimeWindow() to equal 86400"
        );
        assertEq(localRebalancer.nonce(), 0, "expected localRebalancer.nonce() to equal 0");
    }

    function test_unit_constructor_success_withInitData() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(mWethHost);

        address[] memory bridges = new address[](1);
        bridges[0] = address(bridgeMock);

        uint32[] memory destinations = new uint32[](2);
        destinations[0] = 10;
        destinations[1] = 11;

        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        Rebalancer.BridgeTokens[] memory bridgeTokens = new Rebalancer.BridgeTokens[](1);
        bridgeTokens[0] = Rebalancer.BridgeTokens({bridge: address(bridgeMock), tokens: tokens});

        Rebalancer.InitInfo memory initInfo = Rebalancer.InitInfo({
            bridgeTokens: bridgeTokens, markets: markets, bridges: bridges, destinations: destinations
        });

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        Rebalancer localRebalancer = new Rebalancer(address(roles), address(this), address(this), abi.encode(initInfo));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            localRebalancer.whitelistedMarkets(address(market)),
            "expected condition to be true: localRebalancer.whitelistedMarkets(address(market))"
        );
        assertTrue(
            localRebalancer.allowedList(address(market)),
            "expected condition to be true: localRebalancer.allowedList(address(market))"
        );
        assertTrue(
            localRebalancer.whitelistedMarkets(address(mWethHost)),
            "expected condition to be true: localRebalancer.whitelistedMarkets(address(mWethHost))"
        );
        assertTrue(
            localRebalancer.allowedList(address(mWethHost)),
            "expected condition to be true: localRebalancer.allowedList(address(mWethHost))"
        );

        assertTrue(
            localRebalancer.whitelistedBridges(address(bridgeMock)),
            "expected condition to be true: localRebalancer.whitelistedBridges(address(bridgeMock))"
        );
        assertTrue(
            localRebalancer.isDestinationWhitelisted(10),
            "expected condition to be true: localRebalancer.isDestinationWhitelisted(10)"
        );
        assertTrue(
            localRebalancer.isDestinationWhitelisted(11),
            "expected condition to be true: localRebalancer.isDestinationWhitelisted(11)"
        );

        assertTrue(
            localRebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)),
            "expected condition to be true: localRebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth))"
        );
        assertTrue(
            localRebalancer.allowedTokensPerBridge(address(bridgeMock), address(usdc)),
            "expected condition to be true: localRebalancer.allowedTokensPerBridge(address(bridgeMock), address(usdc))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                      InitFirewall                      //
    ////////////////////////////////////////////////////////////

    function test_unit_initFirewall_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockFirewall firewall = new MockFirewall();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.initFirewall(address(firewall));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.hypernativeFirewallAdmin(),
            address(this),
            "expected rebalancer.hypernativeFirewallAdmin() to equal address(this)"
        );

        _allowGuardian();
        rebalancer.setWhitelistedDestination(MAINNET_CHAIN_ID, true);

        assertEq(firewall.validateBlacklistedCount(), 1, "expected firewall.validateBlacklistedCount() to equal 1");
        assertEq(
            firewall.lastBlacklistedSender(),
            address(this),
            "expected firewall.lastBlacklistedSender() to equal address(this)"
        );
    }

    function test_unit_initFirewall_revertsWith_Rebalancer_NotAuthorized() external {
        // Verify admin is address(this), not users.bob

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rebalancer.admin(), address(this), "expected rebalancer.admin() to equal address(this)");

        MockFirewall firewall = new MockFirewall();

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.bob);
        rebalancer.initFirewall(address(firewall));
    }

    ////////////////////////////////////////////////////////////
    //                    FirewallRegister                    //
    ////////////////////////////////////////////////////////////

    function test_unit_firewallRegister_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        vm.store(address(rebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));

        MockFirewallRegister firewall = new MockFirewallRegister();
        rebalancer.setFirewall(address(firewall));
        rebalancer.setIsStrictMode(true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.firewallRegister(users.alice);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(firewall.lastAccount(), users.alice, "expected firewall.lastAccount() to equal users.alice");
        assertTrue(firewall.lastStrict(), "expected condition to be true: firewall.lastStrict()");
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = ALT_CHAIN_ID;
        uint256 amount = 1e18;

        _setupSendMsg(destinationChainId, 0, 10e18);

        IRebalancer.Msg memory message = IRebalancer.Msg({
            dstChainId: destinationChainId, token: address(weth), message: abi.encode(amount), bridgeData: ""
        });

        _getTokens(weth, address(market), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(
            address(bridgeMock), destinationChainId, address(weth), message.message, message.bridgeData
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rebalancer.nonce(), 1, "expected rebalancer.nonce() to equal 1");
        assertEq(
            weth.balanceOf(address(bridgeMock)), amount, "expected weth.balanceOf(address(bridgeMock)) to equal amount"
        );
    }

    function test_unit_sendMsg_success_withFirewallEnabled() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = THIRD_CHAIN_ID;
        uint256 amount = 1e18;

        _enableFirewall();
        _setupSendMsg(destinationChainId, 0, 10e18);

        IRebalancer.Msg memory message = IRebalancer.Msg({
            dstChainId: destinationChainId, token: address(weth), message: abi.encode(amount), bridgeData: ""
        });

        _getTokens(weth, address(market), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(
            address(bridgeMock), destinationChainId, address(weth), message.message, message.bridgeData
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rebalancer.nonce(), 1, "expected rebalancer.nonce() to equal 1");
        assertEq(
            weth.balanceOf(address(bridgeMock)), amount, "expected weth.balanceOf(address(bridgeMock)) to equal amount"
        );
    }

    function test_fuzz_sendMsg_success(uint256 amountRaw, uint32 destinationChainIdRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = bound(amountRaw, 1, 1e24);
        uint32 destinationChainId = uint32(bound(destinationChainIdRaw, 1, type(uint32).max));

        _setupSendMsg(destinationChainId, 0, 0);

        IRebalancer.Msg memory message = IRebalancer.Msg({
            dstChainId: destinationChainId, token: address(weth), message: abi.encode(amount), bridgeData: ""
        });

        _getTokens(weth, address(market), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(
            address(bridgeMock), destinationChainId, address(weth), message.message, message.bridgeData
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(rebalancer.nonce(), 1, "expected rebalancer.nonce() to equal 1");
        assertEq(
            weth.balanceOf(address(bridgeMock)), amount, "expected weth.balanceOf(address(bridgeMock)) to equal amount"
        );

        (uint256 currentSize, uint256 currentTimestamp) =
            rebalancer.currentTransferSize(destinationChainId, address(weth));
        assertEq(currentSize, amount, "expected currentSize to equal amount");
        assertEq(currentTimestamp, block.timestamp, "expected currentTimestamp to equal block.timestamp");
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: MAINNET_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_BridgeNotWhitelisted() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: MAINNET_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_BridgeNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_RequestNotValid_whenUnderlyingDoesNotMatchMessageToken()
        external
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(MAINNET_CHAIN_ID, true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: MAINNET_CHAIN_ID, token: address(usdc), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_DestinationNotWhitelisted() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: TEST_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_DestinationNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_UnderlyingNotAllowedForBridge() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(MAINNET_CHAIN_ID, true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: MAINNET_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_UnderlyingNotAllowedForBridge.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_TransferSizeMinNotMet_whenAmountBelowMin() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _setupSendMsg(2, 5e18, 0);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: ALT_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeMinNotMet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_TransferSizeMinNotMet_whenMessageAmountBelowMin() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 dstId = 12;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, amount, 0);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeMinNotMet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_MarketNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(THIRD_CHAIN_ID, true);

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
        rebalancer.setMinTransferSize(THIRD_CHAIN_ID, address(weth), 0);

        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message = IRebalancer.Msg({
            dstChainId: THIRD_CHAIN_ID, token: address(weth), message: abi.encode(1e18), bridgeData: ""
        });

        _getTokens(weth, address(market), 1e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_MarketNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_TransferSizeExcedeed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 dstId = 8;
        uint256 amount = 4e18;

        _setupSendMsg(dstId, 0, 6e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 2);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeExcedeed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
    }

    function test_unit_sendMsg_revertsWith_ERC20InsufficientBalance_whenMarketExtractFails()
        external
        givenSenderHasRole(roles.GUARDIAN_BRIDGE())
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 destinationChainId = MAINNET_CHAIN_ID;
        uint256 amount = 1 ether;

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(destinationChainId, true);

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
        rebalancer.setMinTransferSize(destinationChainId, address(weth), 0);
        rebalancer.setMaxTransferSize(destinationChainId, address(weth), 0);

        address[] memory markets = new address[](1);
        markets[0] = address(mWethHost);
        rebalancer.setAllowList(markets, true);

        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory message = IRebalancer.Msg({
            dstChainId: destinationChainId, token: address(weth), message: abi.encode(amount), bridgeData: ""
        });
        uint256 marketBalance = weth.balanceOf(address(mWethHost));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(mWethHost), marketBalance, amount
            )
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), amount, message);
    }

    ////////////////////////////////////////////////////////////
    //                  CurrentTransferSize                   //
    ////////////////////////////////////////////////////////////

    function test_unit_currentTransferSize_success_updatesTransferInfoAndLogs() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 dstId = 4;
        uint256 amount = 2e18;

        _setupSendMsg(dstId, 0, 10e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount);

        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(address(bridgeMock), dstId, address(weth), message.message, message.bridgeData);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(size, amount, "expected size to equal amount");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");

        assertEq(rebalancer.nonce(), 1, "expected rebalancer.nonce() to equal 1");
        (uint32 loggedDst, address loggedToken, bytes memory loggedMessage, bytes memory loggedBridgeData) =
            rebalancer.logs(dstId, 1);
        assertEq(loggedDst, dstId, "expected loggedDst to equal dstId");
        assertEq(loggedToken, address(weth), "expected loggedToken to equal address(weth)");
        assertEq(
            keccak256(loggedMessage),
            keccak256(message.message),
            "expected keccak256(loggedMessage) to equal keccak256(message.message)"
        );
        assertEq(
            keccak256(loggedBridgeData),
            keccak256(message.bridgeData),
            "expected keccak256(loggedBridgeData) to equal keccak256(message.bridgeData)"
        );

        assertEq(
            weth.balanceOf(address(bridgeMock)), amount, "expected weth.balanceOf(address(bridgeMock)) to equal amount"
        );
    }

    function test_unit_currentTransferSize_success_accumulatesWithinWindow() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 dstId = 6;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 10e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 2);

        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(address(bridgeMock), dstId, address(weth), message.message, message.bridgeData);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(address(bridgeMock), dstId, address(weth), message.message, message.bridgeData);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(size, amount * 2, "expected size to equal amount * 2");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");
    }

    function test_unit_currentTransferSize_success_succeedsWhenMaxTransferSizeZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 dstId = 11;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 0);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount);

        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(address(bridgeMock), dstId, address(weth), message.message, message.bridgeData);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(size, amount, "expected size to equal amount");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");
    }

    function test_unit_currentTransferSize_success_resetsWindowAfterDeadline() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 dstId = 7;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 10e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 2);

        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(address(bridgeMock), dstId, address(weth), message.message, message.bridgeData);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        vm.warp(block.timestamp + rebalancer.transferTimeWindow() + 1);

        vm.expectEmit(true, true, true, true);
        emit IRebalancer.MsgSent(address(bridgeMock), dstId, address(weth), message.message, message.bridgeData);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(size, amount, "expected size to equal amount");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");
    }

    modifier givenSenderDoesNotHaveGUARDIAN_BRIDGERole() {
        //does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //                    ExtractFeeParams                    //
    ////////////////////////////////////////////////////////////

    function test_unit_extractFeeParams_success() external pure {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory msge =
            hex"0000000000000000000000000000000000000000000000000000000000000140000000000000000000000000b819a871d20913839c37f316dc914b0570bfc0ee000000000000000000000000176211869ca2b568f2a7d4ee941e073a821ee1ff000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda0291300000000000000000000000000000000000000000000000000000000004908e000000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000021050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000342600000000000000000000000000000000000000000000000000000000068d57c3800000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041640266288fc38585602e100c62f4bdad09957a74b0cd68a70860adcbc2119d02117b14da483dbc26ba437f2da24a22d87a4f8bad9d8183513bbf59af8535ff0a1c00000000000000000000000000000000000000000000000000000000000000"; // your full calldata without selector

        // all of these are unused
        abi.decode(msge, (uint32[], bytes32, address, bytes32, uint256, uint256, uint256, bytes));

        _extractFeeParams(msge);
    }

    ////////////////////////////////////////////////////////////
    //                  IsBridgeWhitelisted                   //
    ////////////////////////////////////////////////////////////

    function test_unit_isBridgeWhitelisted_success_whenUnwhitelisted()
        external
        givenSenderHasRole(roles.GUARDIAN_BRIDGE())
    {
        // it should return true
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bool isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(isWhitelisted, "expected condition to be true: isWhitelisted");
    }

    function test_unit_isBridgeWhitelisted_success() external givenSenderHasRole(roles.GUARDIAN_BRIDGE()) {
        // it should remove bridge from whitelist mapping
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bool isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(isWhitelisted, "expected condition to be true: isWhitelisted");
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), false);
        isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));
        assertFalse(isWhitelisted, "expected condition to be false: isWhitelisted");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _allowGuardian() internal {
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
    }

    function _enableFirewall() internal returns (MockFirewall) {
        MockFirewall firewall = new MockFirewall();
        vm.store(address(rebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));
        rebalancer.setFirewall(address(firewall));
        return firewall;
    }

    function _setupSendMsg(uint32 dstId, uint256 minSize, uint256 maxSize) internal {
        _allowGuardian();

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(dstId, true);

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        address[] memory markets = new address[](1);
        markets[0] = address(market);
        rebalancer.setAllowList(markets, true);

        rebalancer.setMinTransferSize(dstId, address(weth), minSize);
        rebalancer.setMaxTransferSize(dstId, address(weth), maxSize);

        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
    }

    function _extractFeeParams(bytes memory msge)
        private
        pure
        returns (uint256 fee, uint256 deadline, bytes memory sig)
    {
        uint256 feeParamsOffset = BytesLib.toUint256(msge, 0x120);
        uint256 feeParamsPtr = feeParamsOffset; // absolute inside msge

        fee = BytesLib.toUint256(msge, feeParamsPtr);
        deadline = BytesLib.toUint256(msge, feeParamsPtr + 32);

        uint256 sigOffset = BytesLib.toUint256(msge, feeParamsOffset + 64);
        uint256 sigLen = BytesLib.toUint256(msge, feeParamsOffset + sigOffset);
        sig = BytesLib.slice(msge, feeParamsOffset + sigOffset + 32, sigLen);
    }
}
