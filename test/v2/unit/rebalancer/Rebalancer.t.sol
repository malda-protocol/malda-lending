// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IRebalancer} from "src/interfaces/IRebalancer.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";

import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {BaseRebalancerTest} from "test/v2/utils/BaseRebalancerTest.t.sol";
import {
    MockFirewallRegister,
    MockRebalanceMarket,
    RejectEthReceiver
} from "test/v2/mocks/rebalancer/RebalancerMocks.t.sol";

contract RebalancerTest is BaseRebalancerTest {
    function setUp() public override {
        super.setUp();

        market = new MockRebalanceMarket(address(weth));

        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        rebalancer.setMaxTransferSize(0, address(weth), type(uint256).max);
        rebalancer.setMaxTransferSize(MAINNET_CHAIN_ID, address(weth), type(uint256).max);
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), false);
    }

    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);

    MockRebalanceMarket internal market;

    ////////////////////////////////////////////////////////////
    //                   SetMaxTransferSize                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setMaxTransferSize_success_withFirewallEnabled() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
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
        rebalancer.setWhitelistedDestination(MAINNET_CHAIN_ID, true);
        rebalancer.setMinTransferSize(MAINNET_CHAIN_ID, address(weth), 1);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMaxTransferSize(MAINNET_CHAIN_ID, address(weth), 2);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.maxTransferSizes(MAINNET_CHAIN_ID, address(weth)),
            2,
            "expected rebalancer.maxTransferSizes(MAINNET_CHAIN_ID, address(weth)) to equal 2"
        );
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

    ////////////////////////////////////////////////////////////
    //                        SaveEth                         //
    ////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_Rebalancer_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();
        _allowGuardian();

        uint32 dstId = 99;
        uint256 amount = 1e18;

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        vm.expectRevert(IRebalancer.Rebalancer_BridgeNotWhitelisted.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        vm.expectRevert(IRebalancer.Rebalancer_DestinationNotWhitelisted.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        rebalancer.setWhitelistedDestination(dstId, true);
        IRebalancer.Msg memory wrongToken =
            IRebalancer.Msg({dstChainId: dstId, token: address(usdc), message: "", bridgeData: ""});
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, wrongToken);

        vm.expectRevert(IRebalancer.Rebalancer_UnderlyingNotAllowedForBridge.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
        rebalancer.setMinTransferSize(dstId, address(weth), amount + 1);

        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeMinNotMet.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        rebalancer.setMinTransferSize(dstId, address(weth), 0);
        rebalancer.setMaxTransferSize(dstId, address(weth), amount - 1);
        address[] memory markets = new address[](1);
        markets[0] = address(market);
        rebalancer.setAllowList(markets, true);

        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeExcedeed.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        rebalancer.setMaxTransferSize(dstId, address(weth), 0);
        rebalancer.setAllowList(markets, false);
        vm.expectRevert(IRebalancer.Rebalancer_MarketNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
    }

    ////////////////////////////////////////////////////////////
    //                        SaveEth                         //
    ////////////////////////////////////////////////////////////

    function test_unit_saveEth_success_withFirewallEnabled() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Rebalancer localRebalancer = new Rebalancer(address(roles), users.alice, address(this), "");
        MockFirewall firewall = new MockFirewall();
        vm.store(address(localRebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));
        localRebalancer.setFirewall(address(firewall));
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.deal(address(localRebalancer), 1 ether);

        uint256 balanceBefore = users.alice.balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        localRebalancer.saveEth();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            users.alice.balance,
            balanceBefore + 1 ether,
            "expected users.alice.balance to equal balanceBefore + 1 ether"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  CurrentTransferSize                   //
    ////////////////////////////////////////////////////////////

    function test_unit_currentTransferSize_success_withFirewallEnabled_hits_window_and_maxsize_branches() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _enableFirewall();

        uint32 dstId = 99;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 5e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 3);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(size, amount, "expected size to equal amount");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");

        rebalancer.setMaxTransferSize(dstId, address(weth), 0);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
        (size, timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount * 2, "expected size to equal amount * 2");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");

        vm.warp(block.timestamp + rebalancer.transferTimeWindow() + 1);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
        (size, timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount, "expected size to equal amount");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");
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

    ////////////////////////////////////////////////////////////
    //                    SetAllowedTokens                    //
    ////////////////////////////////////////////////////////////

    function test_unit_setAllowedTokens_success_updatesMapping() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

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

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)),
            "expected condition to be true: rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth))"
        );

        rebalancer.setAllowedTokens(address(bridgeMock), tokens, false);
        assertFalse(
            rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)),
            "expected condition to be false: rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                    SetMarketStatus                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketStatus_success_updatesMapping() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(mWethHost);

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

    ////////////////////////////////////////////////////////////
    //                      SetAllowList                      //
    ////////////////////////////////////////////////////////////

    function test_unit_setAllowList_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        address[] memory markets = new address[](1);
        markets[0] = address(market);

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
    //               SetWhitelistedBridgeStatus               //
    ////////////////////////////////////////////////////////////

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

    ////////////////////////////////////////////////////////////
    //               SetWhitelistedDestination                //
    ////////////////////////////////////////////////////////////

    function test_unit_setWhitelistedDestination_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

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
        _allowGuardian();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMinTransferSize(5, address(weth), 123);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.minTransferSizes(5, address(weth)),
            123,
            "expected rebalancer.minTransferSizes(5, address(weth)) to equal 123"
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

    function test_unit_setMaxTransferSize_success_updatesMapping() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        _allowGuardian();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMaxTransferSize(6, address(weth), 456);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            rebalancer.maxTransferSizes(6, address(weth)),
            456,
            "expected rebalancer.maxTransferSizes(6, address(weth)) to equal 456"
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
        _getTokens(weth, address(rebalancer), 2e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.saveTokens(address(weth), address(market));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(weth.balanceOf(address(market)), 2e18, "expected weth.balanceOf(address(market)) to equal 2e18");
    }

    ////////////////////////////////////////////////////////////
    //                        SaveEth                         //
    ////////////////////////////////////////////////////////////

    function test_unit_saveEth_success_transfersToSaveAddress() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        Rebalancer localRebalancer = new Rebalancer(address(roles), users.alice, address(this), "");

        _allowGuardian();
        vm.deal(address(localRebalancer), 1 ether);

        uint256 aliceBalanceBefore = users.alice.balance;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        localRebalancer.saveEth();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            users.alice.balance,
            aliceBalanceBefore + 1 ether,
            "expected users.alice.balance to equal aliceBalanceBefore + 1 ether"
        );
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

    ////////////////////////////////////////////////////////////
    //                       Rebalancer                       //
    ////////////////////////////////////////////////////////////

    function test_unit_rebalancer_success() external {
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

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
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

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        vm.warp(block.timestamp + rebalancer.transferTimeWindow() + 1);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(size, amount, "expected size to equal amount");
        assertEq(timestamp, block.timestamp, "expected timestamp to equal block.timestamp");
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

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
    //               SetWhitelistedBridgeStatus               //
    ////////////////////////////////////////////////////////////

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
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        // it should not set a bridge and revert with Rebalancer_NotAuthorized
    }

    modifier givenSenderHasRoleGUARDIAN_BRIDGE() {
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        _;
    }

    function test_unit_setWhitelistedBridgeStatus_success() external givenSenderHasRoleGUARDIAN_BRIDGE {
        // it should whitelist a bridge

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.BridgeWhitelistedStatusUpdated(address(bridgeMock), true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
    }

    ////////////////////////////////////////////////////////////
    //                  IsBridgeWhitelisted                   //
    ////////////////////////////////////////////////////////////

    function test_unit_isBridgeWhitelisted_success_whenUnwhitelisted() external givenSenderHasRoleGUARDIAN_BRIDGE {
        // it should return true
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bool isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(isWhitelisted, "expected condition to be true: isWhitelisted");
    }

    ////////////////////////////////////////////////////////////
    //                    SetMarketStatus                     //
    ////////////////////////////////////////////////////////////

    function test_unit_setMarketStatus_success() external givenSenderHasRoleGUARDIAN_BRIDGE {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        address[] memory markets = new address[](1);
        markets[0] = address(mWethHost);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.setMarketStatus(markets, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            rebalancer.isMarketWhitelisted(address(mWethHost)),
            "expected condition to be true: rebalancer.isMarketWhitelisted(address(mWethHost))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                  IsBridgeWhitelisted                   //
    ////////////////////////////////////////////////////////////

    function test_unit_isBridgeWhitelisted_success() external givenSenderHasRoleGUARDIAN_BRIDGE {
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

    modifier givenSendMsgIsCalledWithWrongParameters() {
        _;
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_Rebalancer_NotAuthorized_whenSenderDoesNotHaveREBALANCER()
        external
        givenSendMsgIsCalledWithWrongParameters
    {
        // it should revert with Rebalancer_NotAuthorized

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_BridgeNotWhitelisted_whenBridgeIsNotWhitelisted()
        external
        givenSendMsgIsCalledWithWrongParameters
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_BridgeNotWhitelisted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
        // it should revert with Rebalancer_BridgeNotWhitelisted
    }

    function test_unit_sendMsg_revertsWith_Rebalancer_RequestNotValid_whenUnderlyingIsNotTheSameToken()
        external
        givenSendMsgIsCalledWithWrongParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should revert with Rebalancer_RequestNotValid

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(0, true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(usdc), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    modifier givenSendMsgIsCalledWithRightParameters() {
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        _;
    }

    function test_unit_sendMsg_revertsWith_MarketDoesNotHaveEnoughTokens()
        external
        givenSendMsgIsCalledWithRightParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should revert

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    function test_unit_sendMsg_revertsWith(uint256 amount)
        external
        givenSendMsgIsCalledWithRightParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        amount = bound(amount, SMALL, LARGE);

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setMaxTransferSize(0, address(weth), amount - 1);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: abi.encode(amount), bridgeData: ""});
        _getTokens(weth, address(mWethHost), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), amount, _msg);
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
