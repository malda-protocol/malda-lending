// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";
import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockMessageTransmitter, MockTokenMessenger} from "test/mocks/rebalancer/CCTPHelperMocks.t.sol";
import {MockMarket, MockRebalancer} from "test/mocks/rebalancer/AcrossBridgeMocks.t.sol";
import {MockRoles} from "test/mocks/rebalancer/CCTPBridgeRolesMocks.t.sol";
import {CCTPBridgeHarness} from "test/harness/rebalancer/CCTPBridgeHarness.sol";
import {BaseTest} from "test/utils/BaseTest.t.sol";

contract CCTPBridgeTest is BaseTest {
    CCTPBridgeHarness internal bridge;
    ERC20Mock internal token;
    MockTokenMessenger internal messenger;
    MockMessageTransmitter internal transmitter;
    MockRebalancer internal rebalancer;
    MockMarket internal market;
    MockRoles internal roles;

    uint32 internal dstChainId = ALT_CHAIN_ID;
    uint32 internal dstDomain = 200;
    uint32 internal srcDomain = 100;

    function setUp() public override {
        super.setUp();

        token = new ERC20Mock("Test", "Test", 18, address(this), address(0), 0);
        messenger = new MockTokenMessenger();
        transmitter = new MockMessageTransmitter();
        rebalancer = new MockRebalancer();

        roles = new MockRoles();
        roles.grantRebalancer(address(rebalancer));
        roles.grantGuardianBridge(address(this));

        market = new MockMarket(address(token));
        bridge = new CCTPBridgeHarness(address(roles), address(messenger), address(transmitter), address(rebalancer));

        token.mint(address(rebalancer), 1_000_000);

        vm.startPrank(address(rebalancer));
        token.approve(address(bridge), type(uint256).max);
        vm.stopPrank();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        token.approve(address(token), type(uint256).max);

        bridge.harnessSetAcceptedToken(address(token), true);
        bridge.harnessSetDomain(uint32(block.chainid), srcDomain);
        bridge.harnessSetDomain(dstChainId, dstDomain);
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_CCTPBridge_AddressNotValid() external {
        address invalidRebalancer = address(0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new CCTPBridgeHarness(address(roles), address(messenger), address(transmitter), invalidRebalancer);
    }

    function test_unit_constructor_success() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        CCTPBridgeHarness localBridge =
            new CCTPBridgeHarness(address(roles), address(messenger), address(transmitter), address(rebalancer));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(localBridge.roles()),
            address(roles),
            "expected address(localBridge.roles()) to equal address(roles)"
        );
        assertEq(
            localBridge.REBALANCER(),
            address(rebalancer),
            "expected localBridge.REBALANCER() to equal address(rebalancer)"
        );
        assertEq(
            localBridge.TOKEN_MESSENGER(),
            address(messenger),
            "expected localBridge.TOKEN_MESSENGER() to equal address(messenger)"
        );
        assertEq(
            localBridge.MESSAGE_TRANSMITTER(),
            address(transmitter),
            "expected localBridge.MESSAGE_TRANSMITTER() to equal address(transmitter)"
        );
    }

    ////////////////////////////////////////////////////////////
    //                     setDomainMapping                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setDomainMapping_success(uint32 chainId, uint32 domain) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        chainId = uint32(bound(chainId, 1, type(uint32).max));
        domain = uint32(bound(domain, 1, type(uint32).max));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit CCTPBridge.DomainMappingUpdated(chainId, domain);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setDomainMapping(chainId, domain);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.chainIdToDomain(chainId), domain, "expected bridge.chainIdToDomain(chainId) to equal domain");
        assertTrue(bridge.domainSet(chainId), "expected condition to be true: bridge.domainSet(chainId)");
    }

    function test_unit_setDomainMapping_revertsWith_BaseBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        bridge.setDomainMapping(dstChainId, dstDomain);
    }

    ////////////////////////////////////////////////////////////
    //                     setAcceptedToken                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setAcceptedToken_success(bool allowed) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ERC20Mock other = new ERC20Mock("Other", "O", 18, address(this), address(0), 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit CCTPBridge.TokenAccepted(address(other), allowed);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setAcceptedToken(address(other), allowed);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            bridge.acceptedTokens(address(other)),
            allowed,
            "expected bridge.acceptedTokens(address(other)) to equal allowed"
        );
    }

    function test_unit_setAcceptedToken_revertsWith_BaseBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(users.alice);
        bridge.setAcceptedToken(address(token), false);
    }

    ////////////////////////////////////////////////////////////
    //                         sendMsg                        //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint8 payloadId = 1;
        uint64 nonce = 0;
        uint256 amount = 1000;
        uint256 balanceBeforeRebalancer = token.balanceOf(address(rebalancer));
        uint256 balanceBeforeBridge = token.balanceOf(address(bridge));
        bytes memory payload = abi.encode(address(market));
        bytes32 receiver = bytes32(uint256(uint160(address(bridge))));
        bytes32 expectedToken = bytes32(uint256(uint160(address(token))));
        bytes32 expectedFrom = bytes32(uint256(uint160(address(rebalancer))));
        bytes memory encodedMessage = abi.encodePacked(
            payloadId,
            expectedToken,
            amount,
            srcDomain,
            dstDomain,
            nonce,
            expectedFrom,
            receiver,
            uint16(payload.length),
            payload
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit CCTPHelper.BurnInitiated(address(token), amount, dstDomain, receiver, nonce, payload);
        vm.expectEmit(true, true, true, true);
        emit CCTPHelper.MessageCreated(
            expectedToken, amount, srcDomain, dstDomain, nonce, expectedFrom, receiver, payload, encodedMessage
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge.sendMsg(amount, address(market), dstChainId, address(token), "", "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            token.balanceOf(address(rebalancer)),
            balanceBeforeRebalancer - amount,
            "expected token.balanceOf(address(rebalancer)) to equal balanceBeforeRebalancer - amount"
        );
        assertEq(
            token.balanceOf(address(bridge)),
            balanceBeforeBridge + amount,
            "expected token.balanceOf(address(bridge)) to equal balanceBeforeBridge + amount"
        );

        assertEq(messenger.lastCaller(), address(bridge), "expected messenger.lastCaller() to equal address(bridge)");
        assertEq(messenger.lastToken(), address(token), "expected messenger.lastToken() to equal address(token)");
        assertEq(messenger.lastAmount(), amount, "expected messenger.lastAmount() to equal amount");
        assertEq(messenger.lastDst(), dstDomain, "expected messenger.lastDst() to equal dstDomain");
        assertEq(
            messenger.lastReceiver(),
            bytes32(uint256(uint160(address(bridge)))),
            "expected messenger.lastReceiver() to equal bytes32(uint256(uint160(address(bridge))))"
        );
        assertEq(
            keccak256(messenger.lastPayload()),
            keccak256(abi.encode(address(market))),
            "expected keccak256(messenger.lastPayload()) to equal keccak256(abi.encode(address(market)))"
        );
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenAmountZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge.sendMsg(0, address(market), dstChainId, address(token), "", "");
    }

    function test_unit_sendMsg_revertsWith_CCTPHelper_TokenNotAccepted() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bridge.setAcceptedToken(address(token), false);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_TokenNotAccepted.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge.sendMsg(1, address(market), dstChainId, address(token), "", "");
    }

    function test_unit_sendMsg_revertsWith_CCTPBridge_DomainNotSet_whenDstNotSet() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        CCTPBridgeHarness bridge2 =
            new CCTPBridgeHarness(address(roles), address(messenger), address(transmitter), address(rebalancer));

        bridge2.harnessSetAcceptedToken(address(token), true);
        bridge2.harnessSetDomain(uint32(block.chainid), srcDomain);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_DomainNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge2.sendMsg(1000, address(market), dstChainId, address(token), "", "");
    }

    function test_unit_sendMsg_revertsWith_CCTPBridge_DomainNotSet_whenSrcNotSet() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        CCTPBridgeHarness bridge2 =
            new CCTPBridgeHarness(address(roles), address(messenger), address(transmitter), address(rebalancer));

        bridge2.harnessSetAcceptedToken(address(token), true);
        bridge2.harnessSetDomain(dstChainId, dstDomain);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_DomainNotSet.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge2.sendMsg(1000, address(market), dstChainId, address(token), "", "");
    }

    // NOTE (as of 2026-02-11): unreachable invariant.
    // `createAndBurn` returns `CCTPMessage.amount` from the same `_extractedAmount` argument,
    // so `cctpMsg.amount != _extractedAmount` in `sendMsg` cannot be reached with current code.
    function test_unit_unreachableInvariant_sendMsgMessageAmountAlwaysMatchesInput() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 777;

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge.sendMsg(amount, address(market), dstChainId, address(token), "", "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(messenger.lastAmount(), amount, "expected messenger.lastAmount() to equal amount");
    }

    ////////////////////////////////////////////////////////////
    //                    handleCCTPMessage                   //
    ////////////////////////////////////////////////////////////

    function test_unit_handleCCTPMessage_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 500;
        token.mint(address(bridge), amount);
        rebalancer.setWhitelisted(address(market), true);

        bytes memory payload = abi.encode(address(market));
        bytes memory hook = _encodeHook(
            bytes32(uint256(uint160(address(token)))),
            amount,
            srcDomain,
            dstDomain,
            777,
            bytes32(uint256(uint160(address(rebalancer)))),
            bytes32(uint256(uint160(address(bridge)))),
            payload
        );
        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), hook);

        uint256 balanceBeforeMarket = token.balanceOf(address(market));
        uint256 balanceBeforeBridge = token.balanceOf(address(bridge));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit CCTPBridge.Rebalanced(address(market), amount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            token.balanceOf(address(market)),
            balanceBeforeMarket + amount,
            "expected token.balanceOf(address(market)) to equal balanceBeforeMarket + amount"
        );
        assertEq(
            token.balanceOf(address(bridge)),
            balanceBeforeBridge - amount,
            "expected token.balanceOf(address(bridge)) to equal balanceBeforeBridge - amount"
        );
    }

    function test_unit_handleCCTPMessage_revertsWith_CCTPBridge_InvalidReceiver() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory payload = abi.encode(address(market));
        bytes memory hook = _encodeHook(
            bytes32(uint256(uint160(address(token)))),
            100,
            srcDomain,
            dstDomain,
            777,
            bytes32(uint256(uint160(address(rebalancer)))),
            bytes32(uint256(uint160(address(bridge)))),
            payload
        );
        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), hook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_InvalidReceiver.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    function test_unit_handleCCTPMessage_revertsWith_CCTPBridge_TokenMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 500;
        token.mint(address(bridge), amount);

        MockMarket badMarket = new MockMarket(users.bob);
        rebalancer.setWhitelisted(address(badMarket), true);

        bytes memory payload = abi.encode(address(badMarket));
        bytes memory hook = _encodeHook(
            bytes32(uint256(uint160(address(token)))),
            amount,
            srcDomain,
            dstDomain,
            777,
            bytes32(uint256(uint160(address(rebalancer)))),
            bytes32(uint256(uint160(address(bridge)))),
            payload
        );
        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), hook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    function test_unit_handleCCTPMessage_revertsWith_CCTPHelper_ReceiveFailed() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        transmitter.setShouldSucceed(false);

        bytes memory payload = abi.encode(address(market));
        bytes memory hook = _encodeHook(
            bytes32(uint256(uint160(address(token)))),
            100,
            srcDomain,
            dstDomain,
            777,
            bytes32(uint256(uint160(address(rebalancer)))),
            bytes32(uint256(uint160(address(bridge)))),
            payload
        );
        bytes memory fakeCCTPMessage = bytes.concat(new bytes(148), new bytes(228), hook);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPHelper.CCTPHelper_ReceiveFailed.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    ////////////////////////////////////////////////////////////
    //                          getFee                        //
    ////////////////////////////////////////////////////////////

    function test_unit_getFee_revertsWith_CCTPBridge_NotImplemented() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(CCTPBridge.CCTPBridge_NotImplemented.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(dstChainId, "", "");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _encodeHook(
        bytes32 tokenB32,
        uint256 amount,
        uint32 srcChain,
        uint32 dstChain,
        uint64 nonce,
        bytes32 from,
        bytes32 receiver,
        bytes memory payload
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(1), tokenB32, amount, srcChain, dstChain, nonce, from, receiver, uint16(payload.length), payload
        );
    }
}
