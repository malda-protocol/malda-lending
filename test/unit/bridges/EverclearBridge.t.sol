// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";

import {EverclearBridge} from "src/rebalancer/bridges/EverclearBridge.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {IFeeAdapter} from "src/interfaces/external/everclear/IFeeAdapter.sol";
import {Roles} from "src/Roles.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {EverclearFeeAdapterMock} from "test/mocks/EverclearFeeAdapterMock.sol";

contract EverclearBridgeTest is Test {
    event MsgSent(uint256 indexed dstChainId, address indexed market, uint256 amountLD, bytes32 id);
    event RebalancingReturnedToMarket(address indexed market, uint256 toReturn, uint256 extracted);

    Roles internal roles;
    ERC20Mock internal token;
    EverclearFeeAdapterMock internal feeAdapter;
    EverclearBridge internal bridge;

    address internal rebalancer;
    address internal guardian;
    address internal market;

    function setUp() public {
        roles = new Roles(address(this));
        feeAdapter = new EverclearFeeAdapterMock();
        bridge = new EverclearBridge(address(roles), address(feeAdapter));
        token = new ERC20Mock("Mock Token", "MOCK", 18, address(this), address(0), type(uint256).max);

        rebalancer = vm.addr(10);
        guardian = vm.addr(11);
        market = vm.addr(12);

        roles.allowFor(rebalancer, roles.REBALANCER(), true);
        roles.allowFor(guardian, roles.GUARDIAN_BRIDGE(), true);
    }

    function test_Constructor_RevertWhenRolesZero() public {
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);
        new EverclearBridge(address(0), address(feeAdapter));
    }

    function test_Constructor_RevertWhenFeeAdapterZero() public {
        vm.expectRevert(EverclearBridge.Everclear_AddressNotValid.selector);
        new EverclearBridge(address(roles), address(0));
    }

    function test_GetFee_Reverts() public {
        vm.expectRevert(EverclearBridge.Everclear_NotImplemented.selector);
        bridge.getFee(0, "", "");
    }

    function test_SendMsg_RevertWhenCallerNotRebalancer() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    function test_SendMsg_RevertWhenTokenMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridge.Everclear_TokenMismatch.selector);
        bridge.sendMsg(input.amount, market, dstChainId, address(0xBEEF), message, "");
    }

    function test_SendMsg_RevertWhenAmountMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 2;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_SendMsg_RevertWhenAmountIsZero() public {
        IntentInput memory input = _defaultInput();
        input.amount = 0;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);
        bridge.sendMsg(0, market, dstChainId, address(token), message, "");
    }

    function test_SendMsg_RevertWhenReceiverMismatch() public {
        IntentInput memory input = _defaultInput();
        input.receiver = address(0xCAFE);
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_SendMsg_RevertWhenDestinationsLengthMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(2, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridge.Everclear_DestinationsLengthMismatch.selector);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_SendMsg_RevertWhenDestinationMismatch() public {
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridge.Everclear_DestinationNotValid.selector);
        bridge.sendMsg(1, market, dstChainId + 1, address(token), message, "");
    }

    function test_SendMsg_RevertWhenMaxFeeExceeded(uint96 amountRaw, uint24 maxFeeRaw) public {
        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 10_000_000);
        input.maxFee = uint24(bound(uint256(maxFeeRaw), input.amount / 10 + 1, type(uint24).max));

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        vm.prank(rebalancer);
        vm.expectRevert(EverclearBridge.Everclear_MaxFeeExceeded.selector);
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    function test_SendMsg_ReturnsExcess_fuzz(
        uint96 amountRaw,
        uint96 feeRaw,
        uint96 extraRaw,
        uint24 maxFeeRaw,
        uint48 ttl,
        bytes memory data,
        bytes memory sig,
        uint256 deadline
    ) public {
        vm.assume(data.length <= 64);
        vm.assume(sig.length <= 64);

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.fee = bound(feeRaw, 0, input.amount / 2);
        input.maxFee = uint24(bound(uint256(maxFeeRaw), 0, input.amount / 10));
        input.ttl = ttl;
        input.data = data;
        input.deadline = deadline;
        input.sig = sig;
        uint256 extra = bound(extraRaw, 1, 1e18);

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.fee + extra;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        vm.expectEmit(true, true, false, true);
        emit RebalancingReturnedToMarket(market, extra, extractedAmount);
        vm.expectEmit(true, true, false, true);
        emit MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        assertEq(token.balanceOf(market), extra);
        assertEq(token.balanceOf(address(bridge)), input.amount + input.fee);
        assertEq(token.allowance(address(bridge), address(feeAdapter)), input.amount + input.fee);
        assertEq(feeAdapter.callCount(), 1);
        assertEq(feeAdapter.lastDestinations(0), dstChainId);
        assertEq(feeAdapter.lastAmount(), input.amount);

        (uint256 storedFee, uint256 storedDeadline, bytes memory storedSig) = feeAdapter.lastFeeParams();
        assertEq(storedFee, input.fee);
        assertEq(storedDeadline, input.deadline);
        assertEq(keccak256(storedSig), keccak256(input.sig));
    }

    function test_SendMsg_NoExcess_fuzz(
        uint96 amountRaw,
        uint96 feeRaw,
        uint24 maxFeeRaw,
        uint48 ttl,
        bytes memory data,
        bytes memory sig,
        uint256 deadline
    ) public {
        vm.assume(data.length <= 64);
        vm.assume(sig.length <= 64);

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.fee = bound(feeRaw, 0, input.amount / 2);
        input.maxFee = uint24(bound(uint256(maxFeeRaw), 0, input.amount / 10));
        input.ttl = ttl;
        input.data = data;
        input.deadline = deadline;
        input.sig = sig;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.fee;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        vm.expectEmit(true, true, false, true);
        emit MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        assertEq(token.balanceOf(market), 0);
        assertEq(token.balanceOf(address(bridge)), input.amount + input.fee);
        assertEq(token.allowance(address(bridge), address(feeAdapter)), input.amount + input.fee);
        assertEq(feeAdapter.callCount(), 1);
        assertEq(feeAdapter.lastDestinations(0), dstChainId);
    }

    struct IntentInput {
        address receiver;
        address inputAsset;
        bytes32 outputAsset;
        uint256 amount;
        uint24 maxFee;
        uint48 ttl;
        bytes data;
        uint256 fee;
        uint256 deadline;
        bytes sig;
    }

    function _defaultInput() internal view returns (IntentInput memory input) {
        input.receiver = market;
        input.inputAsset = address(token);
        input.outputAsset = bytes32(uint256(1));
    }

    function _buildMessage(uint32 destinationsLength, IntentInput memory input)
        internal
        pure
        returns (bytes memory message, uint32 dstChainId)
    {
        uint32[] memory destinations = new uint32[](destinationsLength);
        bytes32 receiverBytes = bytes32(uint256(uint160(input.receiver)));
        bytes memory base = abi.encode(
            destinations,
            receiverBytes,
            input.inputAsset,
            input.outputAsset,
            input.amount,
            input.maxFee,
            input.ttl,
            input.data
        );
        uint32 offset = uint32(base.length);

        if (destinationsLength > 0) {
            destinations[0] = offset;
        }
        if (destinationsLength > 1) {
            destinations[1] = offset + 1;
        }

        base = abi.encode(
            destinations,
            receiverBytes,
            input.inputAsset,
            input.outputAsset,
            input.amount,
            input.maxFee,
            input.ttl,
            input.data
        );

        bytes memory feeParamsData = abi.encode(input.fee, input.deadline, input.sig);
        message = abi.encodePacked(IFeeAdapter.newIntent.selector, base, feeParamsData);
        dstChainId = destinationsLength > 0 ? destinations[0] : 0;
    }
}
