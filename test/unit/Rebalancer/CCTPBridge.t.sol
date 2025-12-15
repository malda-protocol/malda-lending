// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import "forge-std/Test.sol";

import {CCTPHelper} from "src/rebalancer/bridges/cctp/CCTPHelper.sol";
import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";

import {IMessageTransmitterV2} from "src/interfaces/external/cctp/IMessageTransmitterV2.sol";
import {ITokenMessangerV2} from "src/interfaces/external/cctp/ITokenMessangerV2.sol";

import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

contract MockTokenMessenger is ITokenMessangerV2 {
    address public lastToken;
    uint256 public lastAmount;
    uint32 public lastDst;
    bytes32 public lastReceiver;
    bytes32 public lastDestinationCaller;
    uint256 public lastMaxFee;
    uint32 public lastMinFinalityThreshold;
    bytes public lastPayload;
    address public lastCaller;

    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external override {
        lastCaller = msg.sender;
        lastAmount = amount;
        lastDst = destinationDomain;
        lastReceiver = mintRecipient;
        lastToken = burnToken;
        lastDestinationCaller = destinationCaller;
        lastMaxFee = maxFee;
        lastMinFinalityThreshold = minFinalityThreshold;
        lastPayload = hookData;
    }
}

contract MockMessageTransmitter is IMessageTransmitterV2 {
    bool public shouldSucceed = true;
    bytes public lastMessage;
    bytes public lastAttestation;

    function setShouldSucceed(bool val) external {
        shouldSucceed = val;
    }

    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external override returns (bool) {
        lastMessage = message;
        lastAttestation = attestation;
        return shouldSucceed;
    }
}

contract MockRebalancer {
    mapping(address => bool) public whitelisted;

    function setWhitelisted(address market, bool status) external {
        whitelisted[market] = status;
    }

    function isMarketWhitelisted(address market) external view returns (bool) {
        return whitelisted[market];
    }
}

contract MockMarket {
    address public _underlying;

    constructor(address underlying_) {
        _underlying = underlying_;
    }

    function underlying() external view returns (address) {
        return _underlying;
    }
}

contract MockRoles {
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");

    mapping(address => mapping(bytes32 => bool)) public permissions;

    function grantRebalancer(address who) external {
        permissions[who][REBALANCER_ROLE] = true;
    }

    function REBALANCER() external pure returns (bytes32) {
        return REBALANCER_ROLE;
    }

    function isAllowedFor(address account, bytes32 role) external view returns (bool) {
        return permissions[account][role];
    }
}

contract CCTPBridgeHarness is CCTPBridge {
    constructor(
        address _roles,
        address _tokenMessenger,
        address _messageTransmitter,
        address _rebalancer
    ) CCTPBridge(_roles, _tokenMessenger, _messageTransmitter, _rebalancer) {}

    function harnessSetDomain(uint32 chainId, uint32 domain) external {
        chainIdToDomain[chainId] = domain;
        domainSet[chainId] = true;
    }

    function harnessSetAcceptedToken(address token, bool allowed) external {
        acceptedTokens[token] = allowed;
    }
}

contract CCTPBridgeTest is Test {
    CCTPBridgeHarness bridge;
    ERC20Mock token;
    MockTokenMessenger messenger;
    MockMessageTransmitter transmitter;
    MockRebalancer rebalancer;
    MockMarket market;
    MockRoles roles;

    uint32 dstChainId = 2;
    uint32 dstDomain = 200;
    uint32 srcDomain = 100;

    function setUp() public {
        token = new ERC20Mock("Test", "Test", 18, address(this), address(0), 0);
        messenger = new MockTokenMessenger();
        transmitter = new MockMessageTransmitter();
        rebalancer = new MockRebalancer();

        roles = new MockRoles();
        roles.grantRebalancer(address(rebalancer));

        market = new MockMarket(address(token));

        bridge = new CCTPBridgeHarness(
            address(roles),
            address(messenger),
            address(transmitter),
            address(rebalancer)
        );

        token.mint(address(rebalancer), 1_000_000);

        vm.prank(address(rebalancer));
        token.approve(address(bridge), type(uint256).max);
        vm.prank(address(rebalancer));
        token.approve(address(token), type(uint256).max);

        bridge.harnessSetAcceptedToken(address(token), true);
        bridge.harnessSetDomain(uint32(block.chainid), srcDomain);
        bridge.harnessSetDomain(dstChainId, dstDomain);
    }

    function test_sendMsg_success() public {
        uint256 amount = 1000;

        uint256 balanceBeforeRebalancer = token.balanceOf(address(rebalancer));
        uint256 balanceBeforeBridge = token.balanceOf(address(bridge));

        vm.prank(address(rebalancer));
        bridge.sendMsg(
            amount,
            address(market),
            dstChainId,
            address(token),
            "",
            ""
        );

        assertEq(token.balanceOf(address(rebalancer)), balanceBeforeRebalancer - amount);
        assertEq(token.balanceOf(address(bridge)), balanceBeforeBridge + amount);

        assertEq(messenger.lastCaller(), address(bridge));
        assertEq(messenger.lastToken(), address(token));
        assertEq(messenger.lastAmount(), amount);
        assertEq(messenger.lastDst(), dstDomain);
        assertEq(messenger.lastReceiver(), bytes32(uint256(uint160(address(bridge)))));
        assertEq(keccak256(messenger.lastPayload()), keccak256(abi.encode(address(market))));
    }

    function test_sendMsg_revert_zero_amount() public {
        vm.prank(address(rebalancer));
        vm.expectRevert(); // BaseBridge_AmountMismatch
        bridge.sendMsg(
            0,
            address(market),
            dstChainId,
            address(token),
            "",
            ""
        );
    }

    function test_sendMsg_revert_domain_not_set_dst() public {
        // srcDomain set, dstDomain NOT set
        CCTPBridgeHarness bridge2 = new CCTPBridgeHarness(
            address(roles),
            address(messenger),
            address(transmitter),
            address(rebalancer)
        );

        bridge2.harnessSetAcceptedToken(address(token), true);
        bridge2.harnessSetDomain(uint32(block.chainid), srcDomain);
        // bridge2.harnessSetDomain(dstChainId, dstDomain); // intentionally missing

        vm.prank(address(rebalancer));
        vm.expectRevert(CCTPBridge.CCTPBridge_DomainNotSet.selector);
        bridge2.sendMsg(
            1000,
            address(market),
            dstChainId,
            address(token),
            "",
            ""
        );
    }

    function test_handleCCTPMessage_success() public {
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

        bytes memory fakeCCTPMessage = bytes.concat(
            new bytes(148),
            new bytes(228),
            hook
        );

        uint256 balanceBeforeMarket = token.balanceOf(address(market));
        uint256 balanceBeforeBridge = token.balanceOf(address(bridge));

        bridge.handleCCTPMessage(fakeCCTPMessage, "att");

        assertEq(token.balanceOf(address(market)), balanceBeforeMarket + amount);
        assertEq(token.balanceOf(address(bridge)), balanceBeforeBridge - amount);
    }

    function test_sendMsg_revert_domain_not_set_src() public {
        // dstDomain set, srcDomain NOT set
        CCTPBridgeHarness bridge2 = new CCTPBridgeHarness(
            address(roles),
            address(messenger),
            address(transmitter),
            address(rebalancer)
        );

        bridge2.harnessSetAcceptedToken(address(token), true);
        bridge2.harnessSetDomain(dstChainId, dstDomain);

        vm.prank(address(rebalancer));
        vm.expectRevert(CCTPBridge.CCTPBridge_DomainNotSet.selector);
        bridge2.sendMsg(
            1000,
            address(market),
            dstChainId,
            address(token),
            "",
            ""
        );
    }

    function test_sendMsg_domain_set_ok() public {
        uint256 amount = 1000;

        bridge.harnessSetAcceptedToken(address(token), true);
        bridge.harnessSetDomain(uint32(block.chainid), srcDomain);
        bridge.harnessSetDomain(dstChainId, dstDomain);

        vm.prank(address(rebalancer));
        bridge.sendMsg(
            amount,
            address(market),
            dstChainId,
            address(token),
            "",
            ""
        );

        assertEq(messenger.lastDst(), dstDomain);
    }

    function test_handleCCTPMessage_revert_not_whitelisted() public {
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

        bytes memory fakeCCTPMessage = bytes.concat(
            new bytes(148),
            new bytes(228),
            hook
        );

        vm.expectRevert(CCTPBridge.CCTPBridge_InvalidReceiver.selector);
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    function test_handleCCTPMessage_revert_token_mismatch() public {
        uint256 amount = 500;
        token.mint(address(bridge), amount);

        MockMarket badMarket = new MockMarket(address(0xDEAD));
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

        bytes memory fakeCCTPMessage = bytes.concat(
            new bytes(148),
            new bytes(228),
            hook
        );

        vm.expectRevert(CCTPBridge.CCTPBridge_TokenMismatch.selector);
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
    }

    function test_handleCCTPMessage_revert_receive_failed() public {
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

        bytes memory fakeCCTPMessage = bytes.concat(
            new bytes(148),
            new bytes(228),
            hook
        );

        vm.expectRevert(CCTPHelper.CCTPHelper_ReceiveFailed.selector);
        bridge.handleCCTPMessage(fakeCCTPMessage, "att");
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
            uint8(1),
            tokenB32,
            amount,
            srcChain,
            dstChain,
            nonce,
            from,
            receiver,
            uint16(payload.length),
            payload
        );
    }
}
