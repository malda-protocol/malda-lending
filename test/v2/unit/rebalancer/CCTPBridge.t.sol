// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";
import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockMessageTransmitter, MockTokenMessenger} from "test/v2/mocks/rebalancer/CCTPHelperMocks.t.sol";
import {MockMarket, MockRebalancer} from "test/v2/mocks/rebalancer/AcrossBridgeMocks.t.sol";
import {MockRoles} from "test/v2/mocks/rebalancer/CCTPBridgeRolesMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract CCTPBridgeHarness is CCTPBridge {
    constructor(address _roles, address _tokenMessenger, address _messageTransmitter, address _rebalancer)
        CCTPBridge(_roles, _tokenMessenger, _messageTransmitter, _rebalancer)
    {}

    function harnessSetDomain(uint32 chainId, uint32 domain) external {
        chainIdToDomain[chainId] = domain;
        domainSet[chainId] = true;
    }

    function harnessSetAcceptedToken(address token, bool allowed) external {
        acceptedTokens[token] = allowed;
    }
}

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

        vm.prank(address(rebalancer));
        token.approve(address(bridge), type(uint256).max);
        vm.prank(address(rebalancer));
        token.approve(address(token), type(uint256).max);

        bridge.harnessSetAcceptedToken(address(token), true);
        bridge.harnessSetDomain(uint32(block.chainid), srcDomain);
        bridge.harnessSetDomain(dstChainId, dstDomain);
    }

    ////////////////////////////////////////////////////////////
    //                     setDomainMapping                   //
    ////////////////////////////////////////////////////////////

    function test_unit_setDomainMapping_success_emitsAndStores() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        chainId = uint32(bound(chainId, 1, type(uint32).max));

        vm.expectEmit(true, true, false, true);
        emit CCTPBridge.DomainMappingUpdated(chainId, domain);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setDomainMapping(chainId, domain);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.chainIdToDomain(chainId), domain);
        assertTrue(bridge.domainSet(chainId));
    }

    ////////////////////////////////////////////////////////////
    //                     setAcceptedToken                   //
    ////////////////////////////////////////////////////////////

    function test_fuzz_setAcceptedToken_success_emitsAndStores(bool allowed) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        ERC20Mock other = new ERC20Mock("Other", "O", 18, address(this), address(0), 0);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit CCTPBridge.TokenAccepted(address(other), allowed);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setAcceptedToken(address(other), allowed);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(bridge.acceptedTokens(address(other)), allowed);
    }

    ////////////////////////////////////////////////////////////
    //                         sendMsg                        //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_success_transfersAndBurns() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 1000;
        uint256 balanceBeforeRebalancer = token.balanceOf(address(rebalancer));
        uint256 balanceBeforeBridge = token.balanceOf(address(bridge));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge.sendMsg(amount, address(market), dstChainId, address(token), "", "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(address(rebalancer)), balanceBeforeRebalancer - amount);
        assertEq(token.balanceOf(address(bridge)), balanceBeforeBridge + amount);

        assertEq(messenger.lastCaller(), address(bridge));
        assertEq(messenger.lastToken(), address(token));
        assertEq(messenger.lastAmount(), amount);
        assertEq(messenger.lastDst(), dstDomain);
        assertEq(messenger.lastReceiver(), bytes32(uint256(uint160(address(bridge)))));
        assertEq(keccak256(messenger.lastPayload()), keccak256(abi.encode(address(market))));
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenAmountZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(rebalancer));
        bridge.sendMsg(0, address(market), dstChainId, address(token), "", "");
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

    ////////////////////////////////////////////////////////////
    //                    handleCCTPMessage                   //
    ////////////////////////////////////////////////////////////

    function test_unit_handleCCTPMessage_success_transfersAndEmits() external {
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
        assertEq(token.balanceOf(address(market)), balanceBeforeMarket + amount);
        assertEq(token.balanceOf(address(bridge)), balanceBeforeBridge - amount);
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
