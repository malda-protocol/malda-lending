// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {Roles} from "src/Roles.sol";
import {AccrossBridge} from "src/rebalancer/bridges/AcrossBridge.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

contract MockAcrossSpokePool {
    bytes4 private constant DEPOSIT_V3_NOW_SELECTOR = bytes4(
        keccak256("depositV3Now(address,address,address,address,uint256,uint256,uint256,address,uint32,uint32,bytes)")
    );

    address public lastDepositor;
    address public lastRecipient;
    address public lastInputToken;
    address public lastOutputToken;
    uint256 public lastInputAmount;
    uint256 public lastOutputAmount;
    uint256 public lastDestinationChainId;
    address public lastExclusiveRelayer;
    uint32 public lastFillDeadline;
    uint32 public lastExclusivityDeadline;
    uint256 public lastMessageLength;
    bytes32 public lastMessageWord;

    receive() external payable {}

    fallback() external payable {
        require(msg.sig == DEPOSIT_V3_NOW_SELECTOR, "MockAcrossSpokePool: unknown sel");

        uint256 addressMask = type(uint160).max;
        uint256 uint32Mask = type(uint32).max;
        address depositor;
        address recipient;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        address exclusiveRelayer;
        uint32 fillDeadline;
        uint32 exclusivityDeadline;
        uint256 messageLength;
        bytes32 messageWord;

        assembly {
            depositor := and(calldataload(4), addressMask)
            recipient := and(calldataload(36), addressMask)
            inputToken := and(calldataload(68), addressMask)
            outputToken := and(calldataload(100), addressMask)
            inputAmount := calldataload(132)
            outputAmount := calldataload(164)
            destinationChainId := calldataload(196)
            exclusiveRelayer := and(calldataload(228), addressMask)
            fillDeadline := and(calldataload(260), uint32Mask)
            exclusivityDeadline := and(calldataload(292), uint32Mask)
            let msgOffset := calldataload(324)
            let msgStart := add(4, msgOffset)
            messageLength := calldataload(msgStart)
            messageWord := calldataload(add(msgStart, 32))
        }

        lastDepositor = depositor;
        lastRecipient = recipient;
        lastInputToken = inputToken;
        lastOutputToken = outputToken;
        lastInputAmount = inputAmount;
        lastOutputAmount = outputAmount;
        lastDestinationChainId = destinationChainId;
        lastExclusiveRelayer = exclusiveRelayer;
        lastFillDeadline = fillDeadline;
        lastExclusivityDeadline = exclusivityDeadline;
        lastMessageLength = messageLength;
        lastMessageWord = messageWord;
    }
}

contract MockRebalancer {
    mapping(address market => bool allowed) public whitelisted;

    function setWhitelisted(address market, bool status) external {
        whitelisted[market] = status;
    }

    function isMarketWhitelisted(address market) external view returns (bool) {
        return whitelisted[market];
    }
}

contract MockMarket {
    address public underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }
}

contract AcrossBridgeTest is Test {
    Roles internal roles;
    AccrossBridge internal bridge;
    MockAcrossSpokePool internal spokePool;
    MockRebalancer internal rebalancer;
    ERC20Mock internal token;
    MockMarket internal market;

    function setUp() public {
        roles = new Roles(address(this));
        spokePool = new MockAcrossSpokePool();
        rebalancer = new MockRebalancer();

        token = new ERC20Mock("Token", "TOK", 18, address(this), address(0), type(uint256).max);
        market = new MockMarket(address(token));

        bridge = new AccrossBridge(address(roles), address(spokePool), address(rebalancer));

        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        roles.allowFor(address(this), roles.REBALANCER(), true);
    }

    function _encodeMessage(uint256 inputAmount, uint256 outputAmount, address relayer)
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(address(token), inputAmount, outputAmount, relayer, uint32(100), uint32(200));
    }

    function test_constructor_revertWhenSpokePoolZero() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);
        new AccrossBridge(address(roles), address(0), address(rebalancer));
    }

    function test_constructor_revertWhenRebalancerZero() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);
        new AccrossBridge(address(roles), address(spokePool), address(0));
    }

    function test_setWhitelistedRelayer_revertWhenNotConfigurator() external {
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), false);
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);
        bridge.setWhitelistedRelayer(1, address(0xBEEF), true);
    }

    function test_setWhitelistedRelayer_revertWhenRelayerZero() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);
        bridge.setWhitelistedRelayer(1, address(0), true);
    }

    function test_setWhitelistedRelayer_updatesMapping() external {
        bridge.setWhitelistedRelayer(1, address(0xBEEF), true);
        assertTrue(bridge.isRelayerWhitelisted(1, address(0xBEEF)));
    }

    function test_handleV3AcrossMessage_revertWhenCallerNotSpokePool() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_NotAuthorized.selector);
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(market)));
    }

    function test_handleV3AcrossMessage_revertWhenMarketNotWhitelisted() external {
        vm.prank(address(spokePool));
        vm.expectRevert(AccrossBridge.AcrossBridge_InvalidReceiver.selector);
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(market)));
    }

    function test_handleV3AcrossMessage_revertWhenTokenMismatch() external {
        MockMarket otherMarket = new MockMarket(address(0xBEEF));
        rebalancer.setWhitelisted(address(otherMarket), true);

        vm.prank(address(spokePool));
        vm.expectRevert(AccrossBridge.AcrossBridge_TokenMismatch.selector);
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(otherMarket)));
    }

    function test_handleV3AcrossMessage_transfersToMarket() external {
        rebalancer.setWhitelisted(address(market), true);
        token.mint(address(bridge), 5e18);

        vm.prank(address(spokePool));
        bridge.handleV3AcrossMessage(address(token), 5e18, address(0), abi.encode(address(market)));

        assertEq(token.balanceOf(address(market)), 5e18);
    }

    function test_sendMsg_revertWhenAmountMismatch() external {
        bytes memory message = _encodeMessage(10, 10, address(0xBEEF));

        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);
        bridge.sendMsg(9, address(market), 1, address(token), message, "");
    }

    function test_sendMsg_revertWhenRelayerNotWhitelisted() external {
        bytes memory message = _encodeMessage(10, 10, address(0xBEEF));

        vm.expectRevert(AccrossBridge.AcrossBridge_RelayerNotValid.selector);
        bridge.sendMsg(10, address(market), 1, address(token), message, "");
    }

    function test_sendMsg_revertWhenOutputBelowMin() external {
        bridge.setWhitelistedRelayer(1, address(0xBEEF), true);
        bytes memory message = _encodeMessage(100, 80, address(0xBEEF));

        vm.expectRevert(AccrossBridge.AcrossBridge_MaxFeeExceeded.selector);
        bridge.sendMsg(100, address(market), 1, address(token), message, "");
    }

    function test_sendMsg_transfersAndDeposits() external {
        bridge.setWhitelistedRelayer(1, address(0xBEEF), true);

        uint256 inputAmount = 100;
        uint256 outputAmount = 95;
        bytes memory message = _encodeMessage(inputAmount, outputAmount, address(0xBEEF));

        token.mint(address(this), inputAmount);
        token.approve(address(bridge), inputAmount);

        bridge.sendMsg(inputAmount, address(market), 1, address(token), message, "");

        assertEq(spokePool.lastDepositor(), address(this));
        assertEq(spokePool.lastRecipient(), address(bridge));
        assertEq(spokePool.lastInputToken(), address(token));
        assertEq(spokePool.lastOutputToken(), address(token));
        assertEq(spokePool.lastInputAmount(), inputAmount);
        assertEq(spokePool.lastOutputAmount(), outputAmount);
        assertEq(spokePool.lastDestinationChainId(), 1);
        assertEq(spokePool.lastExclusiveRelayer(), address(0xBEEF));
        assertEq(spokePool.lastFillDeadline(), 100);
        assertEq(spokePool.lastExclusivityDeadline(), 200);
        assertEq(spokePool.lastMessageLength(), 32);
        assertEq(spokePool.lastMessageWord(), bytes32(uint256(uint160(address(market)))));
    }

    function test_getFee_reverts() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_NotImplemented.selector);
        bridge.getFee(1, "", "");
    }
}
