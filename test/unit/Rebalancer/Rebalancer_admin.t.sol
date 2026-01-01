// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRebalancer, IRebalanceMarket} from "src/interfaces/IRebalancer.sol";
import {IHypernativeFirewall} from "src/libraries/HypernativeFirewallProtected.sol";
import {Rebalancer} from "src/rebalancer/Rebalancer.sol";
import {Rebalancer_Unit_Shared} from "../shared/Rebalancer_Unit_Shared.t.sol";

contract MockRebalanceMarket is IRebalanceMarket {
    address public underlying;
    IERC20 public token;

    constructor(address _underlying) {
        underlying = _underlying;
        token = IERC20(_underlying);
    }

    function extractForRebalancing(uint256 amount) external {
        token.transfer(msg.sender, amount);
    }
}

contract MockFirewallRegister is IHypernativeFirewall {
    address public lastAccount;
    bool public lastStrict;

    function register(address account, bool isStrictMode) external {
        lastAccount = account;
        lastStrict = isStrictMode;
    }

    function validateBlacklistedAccountInteraction(address) external {}

    function validateForbiddenAccountInteraction(address) external view {}

    function validateForbiddenContextInteraction(address, address) external view {}
}

contract Rebalancer_admin is Rebalancer_Unit_Shared {
    bytes32 private constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.hypernative.admin")) - 1);

    MockRebalanceMarket internal market;

    function setUp() public override {
        super.setUp();
        market = new MockRebalanceMarket(address(weth));
    }

    function _allowGuardian() internal {
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
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

    function test_setAllowedTokens_revertWhenUnauthorized() external {
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);

        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
    }

    function test_setAllowedTokens_updatesMapping() external {
        _allowGuardian();

        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);

        assertTrue(rebalancer.allowedTokensPerBridge(address(bridgeMock), address(weth)));
        assertTrue(rebalancer.allowedTokensPerBridge(address(bridgeMock), address(usdc)));
    }

    function test_setMarketStatus_updatesMapping() external {
        _allowGuardian();

        address[] memory markets = new address[](2);
        markets[0] = address(market);
        markets[1] = address(mWethHost);

        rebalancer.setMarketStatus(markets, true);

        assertTrue(rebalancer.whitelistedMarkets(address(market)));
        assertTrue(rebalancer.whitelistedMarkets(address(mWethHost)));
    }

    function test_setAllowList_updatesMapping() external {
        _allowGuardian();

        address[] memory markets = new address[](1);
        markets[0] = address(market);

        rebalancer.setAllowList(markets, true);

        assertTrue(rebalancer.allowedList(address(market)));
    }

    function test_setWhitelistedDestination_updatesMapping() external {
        _allowGuardian();

        rebalancer.setWhitelistedDestination(10, true);
        assertTrue(rebalancer.isDestinationWhitelisted(10));
    }

    function test_setMinTransferSize_updatesMapping() external {
        _allowGuardian();

        rebalancer.setMinTransferSize(5, address(weth), 123);
        assertEq(rebalancer.minTransferSizes(5, address(weth)), 123);
    }

    function test_setMaxTransferSize_updatesMapping() external {
        _allowGuardian();

        rebalancer.setMaxTransferSize(6, address(weth), 456);
        assertEq(rebalancer.maxTransferSizes(6, address(weth)), 456);
    }

    function test_saveTokens_revertWhenNotAdmin() external {
        vm.prank(alice);
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.saveTokens(address(weth), address(market));
    }

    function test_saveTokens_revertWhenTokenMismatch() external {
        MockRebalanceMarket otherMarket = new MockRebalanceMarket(address(usdc));
        _getTokens(weth, address(rebalancer), 1e18);

        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);
        rebalancer.saveTokens(address(weth), address(otherMarket));
    }

    function test_saveTokens_transfersToMarket() external {
        _getTokens(weth, address(rebalancer), 2e18);

        rebalancer.saveTokens(address(weth), address(market));
        assertEq(weth.balanceOf(address(market)), 2e18);
    }

    function test_saveEth_transfersToSaveAddress() external {
        Rebalancer localRebalancer = new Rebalancer(address(roles), alice, address(this));

        _allowGuardian();
        vm.deal(address(localRebalancer), 1 ether);

        uint256 aliceBalanceBefore = alice.balance;
        localRebalancer.saveEth();
        assertEq(alice.balance, aliceBalanceBefore + 1 ether);
    }

    function test_firewallRegister_callsFirewall() external {
        vm.store(address(rebalancer), ADMIN_SLOT, bytes32(uint256(uint160(address(this)))));

        MockFirewallRegister firewall = new MockFirewallRegister();
        rebalancer.setFirewall(address(firewall));
        rebalancer.setIsStrictMode(true);

        rebalancer.firewallRegister(address(0xBEEF));
        assertEq(firewall.lastAccount(), address(0xBEEF));
        assertTrue(firewall.lastStrict());
    }

    function test_sendMsg_revertWhenDestinationNotWhitelisted() external {
        _allowGuardian();
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: 99, token: address(weth), message: "", bridgeData: ""});

        vm.expectRevert(IRebalancer.Rebalancer_DestinationNotWhitelisted.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_sendMsg_revertWhenUnderlyingNotAllowed() external {
        _allowGuardian();

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(1, true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: 1, token: address(weth), message: "", bridgeData: ""});

        vm.expectRevert(IRebalancer.Rebalancer_UnderlyingNotAllowedForBridge.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_sendMsg_revertWhenTransferSizeBelowMin() external {
        _setupSendMsg(2, 5e18, 0);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: 2, token: address(weth), message: "", bridgeData: ""});

        vm.expectRevert(IRebalancer.Rebalancer_TransferSizeMinNotMet.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_sendMsg_revertWhenMarketNotAllowed() external {
        _allowGuardian();

        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(3, true);

        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        rebalancer.setAllowedTokens(address(bridgeMock), tokens, true);
        rebalancer.setMinTransferSize(3, address(weth), 0);

        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: 3, token: address(weth), message: abi.encode(1e18), bridgeData: ""});

        _getTokens(weth, address(market), 1e18);
        vm.expectRevert(IRebalancer.Rebalancer_MarketNotValid.selector);
        rebalancer.sendMsg(address(bridgeMock), address(market), 1e18, message);
    }

    function test_sendMsg_updatesTransferInfoAndLogs() external {
        uint32 dstId = 4;
        uint256 amount = 2e18;

        _setupSendMsg(dstId, 0, 10e18);

        IRebalancer.Msg memory message =
            IRebalancer.Msg({dstChainId: dstId, token: address(weth), message: abi.encode(amount), bridgeData: ""});

        _getTokens(weth, address(market), amount);

        rebalancer.sendMsg(address(bridgeMock), address(market), amount, message);

        (uint256 size, uint256 timestamp) = rebalancer.currentTransferSize(dstId, address(weth));
        assertEq(size, amount);
        assertEq(timestamp, 0);

        assertEq(rebalancer.nonce(), 1);
        (uint32 loggedDst, address loggedToken, bytes memory loggedMessage, bytes memory loggedBridgeData) =
            rebalancer.logs(dstId, 1);
        assertEq(loggedDst, dstId);
        assertEq(loggedToken, address(weth));
        assertEq(keccak256(loggedMessage), keccak256(message.message));
        assertEq(keccak256(loggedBridgeData), keccak256(message.bridgeData));

        assertEq(weth.balanceOf(address(bridgeMock)), amount);
    }

    function test_sendMsg_resetsWindowAfterDeadline() external {
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

    function test_sendMsg_revertWhenTransferSizeExceeded() external {
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
}
