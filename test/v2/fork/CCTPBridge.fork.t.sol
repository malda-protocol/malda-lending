// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";
import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";
import {Roles} from "src/Roles.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

contract CCTPBridgeForkTest is BaseForkTest {
    address internal constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant MAINNET_USDC_HOLDER = 0x55FE002aefF02F77364de339a1292923A15844B8;
    address internal constant MAINNET_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address internal constant MAINNET_MSG_TRANSMITTER = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

    // cctp domains
    uint32 internal constant ETH_DOMAIN = 0;
    uint32 internal constant BASE_DOMAIN = 6;
    uint32 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant DEFAULT_SEND_AMOUNT = 100e6;

    Roles internal roles;
    CCTPBridge internal bridge;

    address internal rebalancer;

    function setUp() public override {
        super.setUp();
        _selectEthFork();

        rebalancer = address(this);

        roles = new Roles(address(this));
        roles.allowFor(rebalancer, roles.REBALANCER(), true);
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);

        bridge = new CCTPBridge(address(roles), MAINNET_TOKEN_MESSENGER, MAINNET_MSG_TRANSMITTER, rebalancer);

        bridge.setAcceptedToken(MAINNET_USDC, true);
        bridge.setDomainMapping(uint32(block.chainid), ETH_DOMAIN);
        bridge.setDomainMapping(BASE_CHAIN_ID, BASE_DOMAIN);

        uint256 amount = 1_000e6;
        _fundErc20FromHolder(MAINNET_USDC, MAINNET_USDC_HOLDER, rebalancer, amount);

        IERC20(MAINNET_USDC).approve(address(bridge), type(uint256).max);
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_fork_sendMsg_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint8 payloadId = 1;
        uint64 nonce = 0;
        uint256 amount = DEFAULT_SEND_AMOUNT;

        uint256 balBeforeRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balBeforeBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));

        address fakeMarket = users.bob;
        bytes memory payload = abi.encode(fakeMarket);
        bytes32 recipient = bytes32(uint256(uint160(address(bridge))));
        bytes32 tokenBytes = bytes32(uint256(uint160(MAINNET_USDC)));
        bytes32 from = bytes32(uint256(uint160(rebalancer)));
        bytes memory encodedMessage = abi.encodePacked(
            payloadId,
            tokenBytes,
            amount,
            ETH_DOMAIN,
            BASE_DOMAIN,
            nonce,
            from,
            recipient,
            uint16(payload.length),
            payload
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true, address(bridge));
        emit CCTPHelper.BurnInitiated(MAINNET_USDC, amount, BASE_DOMAIN, recipient, nonce, payload);
        vm.expectEmit(true, true, true, true, address(bridge));
        emit CCTPHelper.MessageCreated(
            tokenBytes, amount, ETH_DOMAIN, BASE_DOMAIN, nonce, from, recipient, payload, encodedMessage
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, fakeMarket, BASE_CHAIN_ID, MAINNET_USDC, "", "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balAfterRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balAfterBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));

        assertEq(
            balBeforeRebalancer - balAfterRebalancer,
            amount,
            "rebalancer USDC balance did not decrease by the bridged amount"
        );
        assertEq(balAfterBridge, balBeforeBridge, "bridge should not hold USDC after burning via TokenMessenger");
    }

    function test_fork_fuzz_sendMsg_success(uint256 amountRaw) public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint8 payloadId = 1;
        uint64 nonce = 0;
        uint256 amount = bound(amountRaw, 1, 300e6);
        uint256 balBeforeRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balBeforeBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));
        address market = users.bob;
        bytes memory payload = abi.encode(market);
        bytes32 recipient = bytes32(uint256(uint160(address(bridge))));
        bytes32 tokenBytes = bytes32(uint256(uint160(MAINNET_USDC)));
        bytes32 from = bytes32(uint256(uint160(rebalancer)));
        bytes memory encodedMessage = abi.encodePacked(
            payloadId,
            tokenBytes,
            amount,
            ETH_DOMAIN,
            BASE_DOMAIN,
            nonce,
            from,
            recipient,
            uint16(payload.length),
            payload
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true, address(bridge));
        emit CCTPHelper.BurnInitiated(MAINNET_USDC, amount, BASE_DOMAIN, recipient, nonce, payload);
        vm.expectEmit(true, true, true, true, address(bridge));
        emit CCTPHelper.MessageCreated(
            tokenBytes, amount, ETH_DOMAIN, BASE_DOMAIN, nonce, from, recipient, payload, encodedMessage
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, market, BASE_CHAIN_ID, MAINNET_USDC, "", "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balAfterRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balAfterBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));

        assertEq(balBeforeRebalancer - balAfterRebalancer, amount, "fuzz: rebalancer spent incorrect amount");
        assertEq(balAfterBridge, balBeforeBridge, "fuzz: bridge retained funds");
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_NotAuthorized() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = DEFAULT_SEND_AMOUNT;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        bridge.sendMsg(amount, users.bob, BASE_CHAIN_ID, MAINNET_USDC, "", "");
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenAmountZero() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(0, users.bob, BASE_CHAIN_ID, MAINNET_USDC, "", "");
    }

    function test_fork_sendMsg_revertsWith_CCTPBridge_DomainNotSet_whenDstNotSet() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = DEFAULT_SEND_AMOUNT;
        uint32 unsetChainId = 999;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_DomainNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, users.bob, unsetChainId, MAINNET_USDC, "", "");
    }

    function test_fork_sendMsg_revertsWith_CCTPHelper_TokenNotAccepted() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = DEFAULT_SEND_AMOUNT;
        bridge.setAcceptedToken(MAINNET_USDC, false);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_TokenNotAccepted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(amount, users.bob, BASE_CHAIN_ID, MAINNET_USDC, "", "");
    }

    function test_fork_setDomainMapping_emitsEvent() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint32 chainId = 10;
        uint32 domain = 1111;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true, address(bridge));
        emit CCTPBridge.DomainMappingUpdated(chainId, domain);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setDomainMapping(chainId, domain);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.chainIdToDomain(chainId), domain, "domain should be mapped");
        assertTrue(bridge.domainSet(chainId), "domain should be marked as set");
    }

    function test_fork_setDomainMapping_revertsWith_BaseBridge_NotAuthorized() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        bridge.setDomainMapping(BASE_CHAIN_ID, BASE_DOMAIN);
    }

    function test_fork_setAcceptedToken_emitsEvent() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bool allowed = false;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true, address(bridge));
        emit CCTPBridge.TokenAccepted(MAINNET_USDC, allowed);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setAcceptedToken(MAINNET_USDC, allowed);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertFalse(bridge.acceptedTokens(MAINNET_USDC), "token should not be accepted");
    }

    function test_fork_setAcceptedToken_revertsWith_BaseBridge_NotAuthorized() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        bridge.setAcceptedToken(MAINNET_USDC, false);
    }

    function test_fork_getFee_revertsWith_CCTPBridge_NotImplemented() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_NotImplemented.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(BASE_CHAIN_ID, "", "");
    }
}
