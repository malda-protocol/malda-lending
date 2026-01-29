// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";
import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockMessageTransmitter, MockTokenMessenger} from "test/v2/mocks/rebalancer/CCTPHelperMocks.t.sol";
import {MockMarket, MockRebalancer} from "test/v2/mocks/rebalancer/AcrossBridgeMocks.t.sol";
import {MockRoles} from "test/v2/mocks/rebalancer/CCTPBridgeRolesMocks.t.sol";

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
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_success_success() public {
        uint256 amount = 1000;

        uint256 balanceBeforeRebalancer = token.balanceOf(address(rebalancer));
        uint256 balanceBeforeBridge = token.balanceOf(address(bridge));

        vm.prank(address(rebalancer));
        bridge.sendMsg(amount, address(market), dstChainId, address(token), "", "");

        assertEq(token.balanceOf(address(rebalancer)), balanceBeforeRebalancer - amount);
        assertEq(token.balanceOf(address(bridge)), balanceBeforeBridge + amount);

        assertEq(messenger.lastCaller(), address(bridge));
        assertEq(messenger.lastToken(), address(token));
        assertEq(messenger.lastAmount(), amount);
        assertEq(messenger.lastDst(), dstDomain);
        assertEq(messenger.lastReceiver(), bytes32(uint256(uint160(address(bridge)))));
        assertEq(keccak256(messenger.lastPayload()), keccak256(abi.encode(address(market))));
    }

    function test_unitSendMsg_revertsWith_revert_zero_amount() public {
        vm.prank(address(rebalancer));
        vm.expectRevert(); // BaseBridge_AmountMismatch
        bridge.sendMsg(0, address(market), dstChainId, address(token), "", "");
    }

    function test_unitSendMsg_revertsWith_revert_domain_not_set_dst() public {
        // srcDomain set, dstDomain NOT set
        CCTPBridgeHarness bridge2 =
            new CCTPBridgeHarness(address(roles), address(messenger), address(transmitter), address(rebalancer));

        bridge2.harnessSetAcceptedToken(address(token), true);
        bridge2.harnessSetDomain(uint32(block.chainid), srcDomain);
        // bridge2.harnessSetDomain(dstChainId, dstDomain); // intentionally missing

        vm.prank(address(rebalancer));
        vm.expectRevert(CCTPBridge.CCTPBridge_DomainNotSet.selector);
        bridge2.sendMsg(1000, address(market), dstChainId, address(token), "", "");
    }

    ////////////////////////////////////////////////////////////
    //                    HandleCCTPMessage                     //
    ////////////////////////////////////////////////////////////

    function test_unitHandleCCTPMessage_success_success() public {
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

        bridge.handleCCTPMessage(fakeCCTPMessage, "att");

        assertEq(token.balanceOf(address(market)), balanceBeforeMarket + amount);
        assertEq(token.balanceOf(address(bridge)), balanceBeforeBridge - amount);
    }

    ////////////////////////////////////////////////////////////
    //                         SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_unitSendMsg_revertsWith_revert_domain_not_set_src() public {
        // dstDomain set, srcDomain NOT set
        CCTPBridgeHarness bridge2 =
            new CCTPBridgeHarness(address(roles), address(messenger), address(transmitter), address(rebalancer));

        bridge2.harnessSetAcceptedToken(address(token), true);
        bridge2.harnessSetDomain(dstChainId, dstDomain);

        vm.prank(address(rebalancer));
        vm.expectRevert(CCTPBridge.CCTPBridge_DomainNotSet.selector);
        bridge2.sendMsg(1000, address(market), dstChainId, address(token), "", "");
    }

    function test_unitSendMsg_success_domain_set_ok() public {
        uint256 amount = 1000;

        bridge.harnessSetAcceptedToken(address(token), true);
        bridge.harnessSetDomain(uint32(block.chainid), srcDomain);
        bridge.harnessSetDomain(dstChainId, dstDomain);

        vm.prank(address(rebalancer));
        bridge.sendMsg(amount, address(market), dstChainId, address(token), "", "");

        assertEq(messenger.lastDst(), dstDomain);
    }

    ////////////////////////////////////////////////////////////
    //                    HandleCCTPMessage                     //
    ////////////////////////////////////////////////////////////

    function test_unitHandleCCTPMessage_revertsWith_revert_not_whitelisted() public {
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

        vm.expectRevert(CCTPBridge.CCTPBridge_InvalidReceiver.selector);
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    function test_unitHandleCCTPMessage_revertsWith_revert_token_mismatch() public {
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

        vm.expectRevert(CCTPBridge.CCTPBridge_TokenMismatch.selector);
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    function test_unitHandleCCTPMessage_revertsWith_revert_receive_failed() public {
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

        vm.expectRevert(CCTPHelper.CCTPHelper_ReceiveFailed.selector);
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    ////////////////////////////////////////////////////////////
    //                          GetFee                          //
    ////////////////////////////////////////////////////////////

    function test_unitGetFee_revertsWith_revertsNotImplemented() public {
        vm.expectRevert(CCTPBridge.CCTPBridge_NotImplemented.selector);
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
