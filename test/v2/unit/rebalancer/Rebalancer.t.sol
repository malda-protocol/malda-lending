// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {IRebalancer} from "src/interfaces/IRebalancer.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {BaseRebalancerTest} from "test/v2/utils/BaseRebalancerTest.t.sol";
import {MockFirewall} from "test/mocks/MockFirewall.sol";
import {
    MockFirewallRegister,
    MockRebalanceMarket,
    RejectEthReceiver
} from "test/v2/mocks/rebalancer/RebalancerMocks.t.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";
import {console} from "forge-std/console.sol";

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

    ////////////////////////////////////////////////////////////
    //                      AdminFunctions                      //
    ////////////////////////////////////////////////////////////

    function test_unitAdminFunctions_success_withFirewallEnabled() external {
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
        rebalancer.setMaxTransferSize(MAINNET_CHAIN_ID, address(weth), 2);
    }

    function test_unitAdminFunctions_revertsWith_revertWhenUnauthorized_withFirewall() external {
        _enableFirewall();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
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
        rebalancer.saveEth();
    }

    ////////////////////////////////////////////////////////////
    //                SetWhitelistedBridgeStatus                //
    ////////////////////////////////////////////////////////////

    function test_unitSetWhitelistedBridgeStatus_revertsWith_revertsOnZeroBridge_withFirewall() external {
        _enableFirewall();
        _allowGuardian();
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);
        rebalancer.setWhitelistedBridgeStatus(address(0), true);
    }

    ////////////////////////////////////////////////////////////
    //                         SaveEth                          //
    ////////////////////////////////////////////////////////////

    function test_unitSaveEth_revertsWith_revertsWhenSaveAddressRejects_withFirewall() external {
        RejectEthReceiver rejector = new RejectEthReceiver();
        Rebalancer localRebalancer = new Rebalancer(address(roles), address(rejector), address(this), "");
        MockFirewall firewall = new MockFirewall();
        vm.store(address(localRebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));
        localRebalancer.setFirewall(address(firewall));
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.deal(address(localRebalancer), 1 ether);

        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);
        localRebalancer.saveEth();
    }

    ////////////////////////////////////////////////////////////
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_revertsWith_revertsForValidationChecks_withFirewall() external {
        _enableFirewall();
        _allowGuardian();

        uint32 dstId = 99;
        uint256 amount = 1e18;

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

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
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
    }

    ////////////////////////////////////////////////////////////
    //                         SaveEth                          //
    ////////////////////////////////////////////////////////////

    function test_unitSaveEth_success_withFirewallEnabled() external {
        Rebalancer localRebalancer = new Rebalancer(address(roles), users.alice, address(this), "");
        MockFirewall firewall = new MockFirewall();
        vm.store(address(localRebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));
        localRebalancer.setFirewall(address(firewall));
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.deal(address(localRebalancer), 1 ether);

        uint256 balanceBefore = users.alice.balance;
        localRebalancer.saveEth();
        assertEq(users.alice.balance, balanceBefore + 1 ether);
    }

    ////////////////////////////////////////////////////////////
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_success_withFirewallEnabled_hits_window_and_maxsize_branches() external {
        _enableFirewall();

        uint32 dstId = 99;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 5e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 3);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount);
        assertEq(timestamp, block.timestamp);

        rebalancer.setMaxTransferSize(dstId, address(weth), 0);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
        (size, timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount * 2);
        assertEq(timestamp, block.timestamp);

        vm.warp(block.timestamp + rebalancer.transferTimeWindow() + 1);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
        (size, timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount);
        assertEq(timestamp, block.timestamp);
    }

    ////////////////////////////////////////////////////////////
    //                     SetAllowedTokens                     //
    ////////////////////////////////////////////////////////////

    function test_unitSetAllowedTokens_revertsWith_revertWhenUnauthorized() external {
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
    }

    ////////////////////////////////////////////////////////////
    //                     SetMarketStatus                      //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketStatus_revertsWith_revertWhenUnauthorized() external {
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setMarketStatus(markets, true);
    }

    ////////////////////////////////////////////////////////////
    //                     SetAllowedTokens                     //
    ////////////////////////////////////////////////////////////

    function test_unitSetAllowedTokens_success_updatesMapping() external {
        _allowGuardian();

        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        assertTrue(rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)));
        assertTrue(rebalancer.allowedTokensPerBridge(address(bridgeMock), address(usdc)));
    }

    function test_unitSetAllowedTokens_success_removesMapping() external {
        _allowGuardian();

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
        assertTrue(rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)));

        rebalancer.setAllowedTokens(address(bridgeMock), tokens, false);
        assertFalse(rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)));
    }

    ////////////////////////////////////////////////////////////
    //                     SetMarketStatus                      //
    ////////////////////////////////////////////////////////////

    function test_unitSetMarketStatus_success_updatesMapping() external {
        _allowGuardian();

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(mWethHost);

        rebalancer.setMarketStatus(markets, true);

        assertTrue(rebalancer.whitelistedMarkets(address(market)));
        assertTrue(rebalancer.whitelistedMarkets(address(mWethHost)));
    }

    ////////////////////////////////////////////////////////////
    //                       SetAllowList                       //
    ////////////////////////////////////////////////////////////

    function test_unitSetAllowList_success_updatesMapping() external {
        _allowGuardian();

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        rebalancer.setAllowList(markets, true);

        assertTrue(rebalancer.allowedList(address(market)));
    }

    function test_unitSetAllowList_revertsWith_revertWhenUnauthorized() external {
        address[] memory markets = new address[](1);
        markets[0] = address(market);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setAllowList(markets, true);
    }

    ////////////////////////////////////////////////////////////
    //                SetWhitelistedBridgeStatus                //
    ////////////////////////////////////////////////////////////

    function test_unitSetWhitelistedBridgeStatus_revertsWith_revertWhenUnauthorized() external {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
    }

    function test_unitSetWhitelistedBridgeStatus_revertsWith_revertsOnZeroBridge() external {
        _allowGuardian();
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);
        rebalancer.setWhitelistedBridgeStatus(address(0), true);
    }

    ////////////////////////////////////////////////////////////
    //                SetWhitelistedDestination                 //
    ////////////////////////////////////////////////////////////

    function test_unitSetWhitelistedDestination_success_updatesMapping() external {
        _allowGuardian();

        rebalancer.setWhitelistedDestination(OPTIMISM_CHAIN_ID, true);
        assertTrue(rebalancer.isDestinationWhitelisted(10));
    }

    function test_unitSetWhitelistedDestination_revertsWith_revertWhenUnauthorized() external {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedDestination(OPTIMISM_CHAIN_ID, true);
    }

    ////////////////////////////////////////////////////////////
    //                    SetMinTransferSize                    //
    ////////////////////////////////////////////////////////////

    function test_unitSetMinTransferSize_success_updatesMapping() external {
        _allowGuardian();

        rebalancer.setMinTransferSize(5, address(weth), 123);
        assertEq(rebalancer.minTransferSizes(5, address(weth)), 123);
    }

    function test_unitSetMinTransferSize_revertsWith_revertWhenUnauthorized() external {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setMinTransferSize(5, address(weth), 123);
    }

    ////////////////////////////////////////////////////////////
    //                    SetMaxTransferSize                    //
    ////////////////////////////////////////////////////////////

    function test_unitSetMaxTransferSize_success_updatesMapping() external {
        _allowGuardian();

        rebalancer.setMaxTransferSize(6, address(weth), 456);
        assertEq(rebalancer.maxTransferSizes(6, address(weth)), 456);
    }

    function test_unitSetMaxTransferSize_revertsWith_revertWhenUnauthorized() external {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setMaxTransferSize(6, address(weth), 456);
    }

    ////////////////////////////////////////////////////////////
    //                         SetAdmin                         //
    ////////////////////////////////////////////////////////////

    function test_unitSetAdmin_success_updatesAdmin() external {
        rebalancer.setAdmin(users.alice);
        assertEq(rebalancer.admin(), users.alice);
    }

    function test_unitSetAdmin_revertsWith_revertWhenUnauthorized() external {
        vm.prank(users.alice);
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setAdmin(users.bob);
    }

    function test_unitSetAdmin_revertsWith_revertWhenZeroAddress() external {
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);
        rebalancer.setAdmin(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                      SetSaveAddress                      //
    ////////////////////////////////////////////////////////////

    function test_unitSetSaveAddress_success_updatesSaveAddress() external {
        rebalancer.setSaveAddress(users.alice);
        assertEq(rebalancer.saveAddress(), users.alice);
    }

    function test_unitSetSaveAddress_revertsWith_revertWhenUnauthorized() external {
        vm.prank(users.alice);
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setSaveAddress(users.bob);
    }

    function test_unitSetSaveAddress_revertsWith_revertWhenZeroAddress() external {
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);
        rebalancer.setSaveAddress(address(0));
    }

    ////////////////////////////////////////////////////////////
    //                        SaveTokens                        //
    ////////////////////////////////////////////////////////////

    function test_unitSaveTokens_revertsWith_revertWhenNotAdmin() external {
        vm.prank(users.alice);
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.saveTokens(address(weth), address(market));
    }

    function test_unitSaveTokens_revertsWith_revertWhenTokenMismatch() external {
        MockRebalanceMarket otherMarket = new MockRebalanceMarket(address(usdc));
        _getTokens(weth, address(rebalancer), 1e18);

        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);
        rebalancer.saveTokens(address(weth), address(otherMarket));
    }

    function test_unitSaveTokens_success_transfersToMarket() external {
        _getTokens(weth, address(rebalancer), 2e18);

        rebalancer.saveTokens(address(weth), address(market));
        assertEq(weth.balanceOf(address(market)), 2e18);
    }

    ////////////////////////////////////////////////////////////
    //                         SaveEth                          //
    ////////////////////////////////////////////////////////////

    function test_unitSaveEth_success_transfersToSaveAddress() external {
        Rebalancer localRebalancer = new Rebalancer(address(roles), users.alice, address(this), "");

        _allowGuardian();
        vm.deal(address(localRebalancer), 1 ether);

        uint256 aliceBalanceBefore = users.alice.balance;
        localRebalancer.saveEth();
        assertEq(users.alice.balance, aliceBalanceBefore + 1 ether);
    }

    function test_unitSaveEth_revertsWith_revertWhenUnauthorized() external {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.saveEth();
    }

    function test_unitSaveEth_revertsWith_revertsWhenSaveAddressRejects() external {
        RejectEthReceiver rejector = new RejectEthReceiver();
        Rebalancer localRebalancer = new Rebalancer(address(roles), address(rejector), address(this), "");

        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        vm.deal(address(localRebalancer), 1 ether);

        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);
        localRebalancer.saveEth();
    }

    ////////////////////////////////////////////////////////////
    //                       Constructor                        //
    ////////////////////////////////////////////////////////////

    function test_unitConstructor_revertsWith_revertsOnZeroAddresses() external {
        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);
        new Rebalancer(address(0), address(this), address(this), "");

        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);
        new Rebalancer(address(roles), address(0), address(this), "");

        vm.expectRevert(IRebalancer.Rebalancer_AddressNotValid.selector);
        new Rebalancer(address(roles), address(this), address(0), "");
    }

    function test_unitConstructor_success_initData_initializesLists() external {
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

        Rebalancer localRebalancer = new Rebalancer(address(roles), address(this), address(this), abi.encode(initInfo));

        assertTrue(localRebalancer.whitelistedMarkets(address(market)));
        assertTrue(localRebalancer.allowedList(address(market)));
        assertTrue(localRebalancer.whitelistedMarkets(address(mWethHost)));
        assertTrue(localRebalancer.allowedList(address(mWethHost)));

        assertTrue(localRebalancer.whitelistedBridges(address(bridgeMock)));
        assertTrue(localRebalancer.isDestinationWhitelisted(10));
        assertTrue(localRebalancer.isDestinationWhitelisted(11));

        assertTrue(localRebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)));
        assertTrue(localRebalancer.allowedTokensPerBridge(address(bridgeMock), address(usdc)));
    }

    ////////////////////////////////////////////////////////////
    //                       InitFirewall                       //
    ////////////////////////////////////////////////////////////

    function test_unitInitFirewall_success_setsAdminAndFirewall() external {
        MockFirewall firewall = new MockFirewall();

        rebalancer.initFirewall(address(firewall));
        assertEq(rebalancer.hypernativeFirewallAdmin(), address(this));

        _allowGuardian();
        rebalancer.setWhitelistedDestination(MAINNET_CHAIN_ID, true);

        assertEq(firewall.validateBlacklistedCount(), 1);
        assertEq(firewall.lastBlacklistedSender(), address(this));
    }

    function test_unitInitFirewall_revertsWith_revertWhenUnauthorized() external {
        // Verify admin is address(this), not users.bob
        assertEq(rebalancer.admin(), address(this));

        MockFirewall firewall = new MockFirewall();

        vm.prank(users.bob);
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.initFirewall(address(firewall));
    }

    ////////////////////////////////////////////////////////////
    //                     FirewallRegister                     //
    ////////////////////////////////////////////////////////////

    function test_unitFirewallRegister_success_callsFirewall() external {
        vm.store(address(rebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));

        MockFirewallRegister firewall = new MockFirewallRegister();
        rebalancer.setFirewall(address(firewall));
        rebalancer.setIsStrictMode(true);

        rebalancer.firewallRegister(users.alice);
        assertEq(firewall.lastAccount(), users.alice);
        assertTrue(firewall.lastStrict());
    }

    ////////////////////////////////////////////////////////////
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_revertsWith_revertWhenDestinationNotWhitelisted() external {
        _allowGuardian();
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: TEST_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        vm.expectRevert(IRebalancer.Rebalancer_DestinationNotWhitelisted.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unitSendMsg_revertsWith_revertWhenUnderlyingNotAllowed() external {
        _allowGuardian();

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(MAINNET_CHAIN_ID, true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: MAINNET_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        vm.expectRevert(IRebalancer.Rebalancer_UnderlyingNotAllowedForBridge.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unitSendMsg_revertsWith_revertWhenTransferSizeBelowMin() external {
        _setupSendMsg(2, 5e18, 0);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: ALT_CHAIN_ID, token: address(weth), message: "", bridgeData: ""});

        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeMinNotMet.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unitSendMsg_revertsWith_revertWhenTransferSizeEqualsMin() external {
        uint32 dstId = 12;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, amount, 0);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount);

        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeMinNotMet.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
    }

    function test_unitSendMsg_revertsWith_revertWhenMarketNotAllowed() external {
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
        vm.expectRevert(IRebalancer.Rebalancer_MarketNotValid.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_unitSendMsg_success_updatesTransferInfoAndLogs() external {
        uint32 dstId = 4;
        uint256 amount = 2e18;

        _setupSendMsg(dstId, 0, 10e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount);
        assertEq(timestamp, block.timestamp);

        assertEq(rebalancer.nonce(), 1);
        (uint32 loggedDst, address loggedToken, bytes memory loggedMessage, bytes memory loggedBridgeData) =
            rebalancer.logs(dstId, 1);
        assertEq(loggedDst, dstId);
        assertEq(loggedToken, address(weth));
        assertEq(keccak256(loggedMessage), keccak256(message.message));
        assertEq(keccak256(loggedBridgeData), keccak256(message.bridgeData));

        assertEq(weth.balanceOf(address(bridgeMock)), amount);
    }

    function test_unitSendMsg_success_accumulatesWithinWindow() external {
        uint32 dstId = 6;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 10e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 2);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount * 2);
        assertEq(timestamp, block.timestamp);
    }

    function test_unitSendMsg_success_succeedsWhenMaxTransferSizeZero() external {
        uint32 dstId = 11;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 0);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount);
        assertEq(timestamp, block.timestamp);
    }

    function test_unitSendMsg_success_resetsWindowAfterDeadline() external {
        uint32 dstId = 7;
        uint256 amount = 1e18;

        _setupSendMsg(dstId, 0, 10e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 2);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        vm.warp(block.timestamp + rebalancer.transferTimeWindow() + 1);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount);
        assertEq(timestamp, block.timestamp);
    }

    function test_unitSendMsg_revertsWith_revertWhenTransferSizeExceeded() external {
        uint32 dstId = 8;
        uint256 amount = 4e18;

        _setupSendMsg(dstId, 0, 6e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount * 2);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeExcedeed.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);
    }

    modifier givenSenderDoesNotHaveGUARDIAN_BRIDGERole() {
        //does nothing; for readability only
        _;
    }

    ////////////////////////////////////////////////////////////
    //                        DecodeFull                        //
    ////////////////////////////////////////////////////////////

    function test_unitDecodeFull_success() external pure {
        bytes memory msge =
            hex"0000000000000000000000000000000000000000000000000000000000000140000000000000000000000000b819a871d20913839c37f316dc914b0570bfc0ee000000000000000000000000176211869ca2b568f2a7d4ee941e073a821ee1ff000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda0291300000000000000000000000000000000000000000000000000000000004908e000000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000021050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000342600000000000000000000000000000000000000000000000000000000068d57c3800000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041640266288fc38585602e100c62f4bdad09957a74b0cd68a70860adcbc2119d02117b14da483dbc26ba437f2da24a22d87a4f8bad9d8183513bbf59af8535ff0a1c00000000000000000000000000000000000000000000000000000000000000"; // your full calldata without selector

        // all of these are unused
        abi.decode(msge, (uint32[], bytes32, address, bytes32, uint256, uint256, uint256, bytes));

        (uint256 fee, uint256 deadline,) = _extractFeeParams(msge);

        console.log("Fee:", fee);
        console.log("Deadline:", deadline);
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

    ////////////////////////////////////////////////////////////
    //      WhenSetWhitelistedBridgeStatusIsCalledWithTrue      //
    ////////////////////////////////////////////////////////////

    function test_unitWhenSetWhitelistedBridgeStatusIsCalledWithTrue_success()
        external
        givenSenderDoesNotHaveGUARDIAN_BRIDGERole
    {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        // it should not set a bridge and revert with Rebalancer_NotAuthorized
    }

    ////////////////////////////////////////////////////////////
    //     WhenSetWhitelistedBridgeStatusIsCalledWithFalse      //
    ////////////////////////////////////////////////////////////

    function test_unitWhenSetWhitelistedBridgeStatusIsCalledWithFalse_success()
        external
        givenSenderDoesNotHaveGUARDIAN_BRIDGERole
    {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        // it should not set a bridge and revert with Rebalancer_NotAuthorized
    }

    modifier givenSenderHasRoleGUARDIAN_BRIDGE() {
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        _;
    }

    ////////////////////////////////////////////////////////////
    //    WhenSetWhitelistedBridgeStatusIsCalledToWhitelist     //
    ////////////////////////////////////////////////////////////

    function test_unitWhenSetWhitelistedBridgeStatusIsCalledToWhitelist_success()
        external
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should whitelist a bridge
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.BridgeWhitelistedStatusUpdated(address(bridgeMock), true);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
    }

    ////////////////////////////////////////////////////////////
    //             WhenIsBridgeWhitelistedIsCalled              //
    ////////////////////////////////////////////////////////////

    function test_unitWhenIsBridgeWhitelistedIsCalled_success() external givenSenderHasRoleGUARDIAN_BRIDGE {
        // it should return true
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        bool isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));
        assertTrue(isWhitelisted);
    }

    ////////////////////////////////////////////////////////////
    //             WhenIsMarketWhitelistedIsCalled              //
    ////////////////////////////////////////////////////////////

    function test_unitWhenIsMarketWhitelistedIsCalled_success() external givenSenderHasRoleGUARDIAN_BRIDGE {
        address[] memory markets = new address[](1);
        markets[0] = address(mWethHost);

        rebalancer.setMarketStatus(markets, true);

        assertTrue(rebalancer.isMarketWhitelisted(address(mWethHost)));
    }

    ////////////////////////////////////////////////////////////
    //WhenSetWhitelistedBridgeStatusIsCalledToRemoveFromWhitelist//
    ////////////////////////////////////////////////////////////

    function test_unitWhenSetWhitelistedBridgeStatusIsCalledToRemoveFromWhitelist_success()
        external
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should remove bridge from whitelist mapping
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        bool isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));
        assertTrue(isWhitelisted);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), false);
        isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));
        assertFalse(isWhitelisted);
    }

    modifier givenSendMsgIsCalledWithWrongParameters() {
        _;
    }

    ////////////////////////////////////////////////////////////
    //             WhenSenderDoesNotHaveREBALANCER              //
    ////////////////////////////////////////////////////////////

    function test_unitWhenSenderDoesNotHaveREBALANCER_success_EOARole()
        external
        givenSendMsgIsCalledWithWrongParameters
    {
        // it should revert with Rebalancer_NotAuthorized
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    ////////////////////////////////////////////////////////////
    //                WhenBridgeIsNotWhitelisted                //
    ////////////////////////////////////////////////////////////

    function test_unitWhenBridgeIsNotWhitelisted_success() external givenSendMsgIsCalledWithWrongParameters {
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});
        vm.expectRevert(IRebalancer.Rebalancer_BridgeNotWhitelisted.selector);
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
        // it should revert with Rebalancer_BridgeNotWhitelisted
    }

    ////////////////////////////////////////////////////////////
    //             WhenUnderlyingIsNotTheSameToken              //
    ////////////////////////////////////////////////////////////

    function test_unitWhenUnderlyingIsNotTheSameToken_success()
        external
        givenSendMsgIsCalledWithWrongParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should revert with Rebalancer_RequestNotValid
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(0, true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(usdc), message: "", bridgeData: ""});
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    modifier givenSendMsgIsCalledWithRightParameters() {
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        _;
    }

    ////////////////////////////////////////////////////////////
    //                        RevertWhen                        //
    ////////////////////////////////////////////////////////////

    function test_unitRevertWhen_revertsWith_MarketDoesNotHaveEnoughTokens()
        external
        givenSendMsgIsCalledWithRightParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should revert
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});
        vm.expectRevert();
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    ////////////////////////////////////////////////////////////
    //     WhenMarketHasEnoughTokensButTransferSizeIsNotMet     //
    ////////////////////////////////////////////////////////////

    function test_unitWhenMarketHasEnoughTokensButTransferSizeIsNotMet_success(uint256 amount)
        external
        givenSendMsgIsCalledWithRightParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        amount = bound(amount, SMALL, LARGE);

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setMaxTransferSize(0, address(weth), amount - 1);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: abi.encode(amount), bridgeData: ""});
        _getTokens(weth, address(mWethHost), amount);
        vm.expectRevert();
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), amount, _msg);
    }
}
