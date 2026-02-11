// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {EverclearBridge} from "src/rebalancer/bridges/EverclearBridge.sol";
import {IFeeAdapter} from "src/interfaces/external/everclear/IFeeAdapter.sol";
import {Roles} from "src/Roles.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {EverclearFeeAdapterMock} from "test/mocks/EverclearFeeAdapterMock.sol";
import {BaseTest} from "test/utils/BaseTest.t.sol";

contract EverclearBridgeTest is BaseTest {
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

    Roles internal roles;
    ERC20Mock internal token;
    EverclearFeeAdapterMock internal feeAdapter;
    EverclearBridge internal bridge;

    address internal rebalancer;
    address internal guardian;
    address internal market;

    function setUp() public override {
        super.setUp();

        roles = new Roles(address(this));
        feeAdapter = new EverclearFeeAdapterMock();
        bridge = new EverclearBridge(address(roles), address(feeAdapter));
        token = new ERC20Mock("Mock Token", "MOCK", 18, address(this), address(0), type(uint256).max);

        rebalancer = users.alice;
        guardian = users.guardian;
        market = users.bob;

        roles.allowFor(rebalancer, roles.REBALANCER(), true);
        roles.allowFor(guardian, roles.GUARDIAN_BRIDGE(), true);
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_BaseBridge_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new EverclearBridge(address(0), address(feeAdapter));
    }

    function test_unit_constructor_revertsWith_Everclear_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridge.Everclear_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new EverclearBridge(address(roles), address(0));
    }

    function test_unit_constructor_success() external {
        // ~~~~~~~~~~ Call ~~~~~~~~~~
        EverclearBridge localBridge = new EverclearBridge(address(roles), address(feeAdapter));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(
            address(localBridge.roles()),
            address(roles),
            "expected address(localBridge.roles()) to equal address(roles)"
        );
        assertEq(
            address(localBridge.everclearFeeAdapter()),
            address(feeAdapter),
            "expected address(localBridge.everclearFeeAdapter()) to equal address(feeAdapter)"
        );
    }

    ////////////////////////////////////////////////////////////
    //                          getFee                        //
    ////////////////////////////////////////////////////////////

    function test_unit_getFee_revertsWith_Everclear_NotImplemented() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridge.Everclear_NotImplemented.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(0, "", "");
    }

    ////////////////////////////////////////////////////////////
    //                          sendMsg                       //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_BaseBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_Everclear_TokenMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridge.Everclear_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(input.amount, market, dstChainId, users.carol, message, "");
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenExtractedLessThanAmount() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 2;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenAmountZero() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 0;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(0, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_BaseBridge_AddressNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.receiver = users.carol;
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_Everclear_DestinationsLengthMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(2, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridge.Everclear_DestinationsLengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_Everclear_DestinationNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = 1;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridge.Everclear_DestinationNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(1, market, dstChainId + 1, address(token), message, "");
    }

    function test_fuzz_sendMsg_revertsWith_Everclear_MaxFeeExceeded(uint96 amountRaw, uint24 maxFeeRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 10_000_000);
        input.maxFee = uint24(bound(uint256(maxFeeRaw), input.amount / 10 + 1, type(uint24).max));

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridge.Everclear_MaxFeeExceeded.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(rebalancer);
        bridge.sendMsg(input.amount, market, dstChainId, address(token), message, "");
    }

    function test_fuzz_sendMsg_success_returnsExcess(
        uint96 amountRaw,
        uint96 feeRaw,
        uint96 extraRaw,
        uint24 maxFeeRaw,
        uint48 ttl,
        bytes calldata data,
        bytes calldata sig,
        uint256 deadline
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 dataLength = bound(data.length, 0, 64);
        bytes memory boundedData = new bytes(dataLength);
        for (uint256 i; i < dataLength; ++i) {
            boundedData[i] = data[i];
        }

        uint256 sigLength = bound(sig.length, 0, 64);
        bytes memory boundedSig = new bytes(sigLength);
        for (uint256 i; i < sigLength; ++i) {
            boundedSig[i] = sig[i];
        }

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.fee = bound(feeRaw, 0, input.amount / 2);
        input.maxFee = uint24(bound(uint256(maxFeeRaw), 0, input.amount / 10));
        input.ttl = ttl;
        input.data = boundedData;
        input.deadline = deadline;
        input.sig = boundedSig;
        uint256 extra = bound(extraRaw, 1, 1e18);

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.fee + extra;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit EverclearBridge.RebalancingReturnedToMarket(market, extra, extractedAmount);
        vm.expectEmit(true, true, false, true);
        emit EverclearBridge.MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(market), extra, "expected token.balanceOf(market) to equal extra");
        assertEq(
            token.balanceOf(address(bridge)),
            input.amount + input.fee,
            "expected token.balanceOf(address(bridge)) to equal input.amount + input.fee"
        );
        assertEq(
            token.allowance(address(bridge), address(feeAdapter)),
            input.amount + input.fee,
            "expected token.allowance(address(bridge), address(feeAdapter)) to equal input.amount + input.fee"
        );
        assertEq(feeAdapter.callCount(), 1, "expected feeAdapter.callCount() to equal 1");
        assertEq(
            feeAdapter.lastDestinations(0), dstChainId, "expected feeAdapter.lastDestinations(0) to equal dstChainId"
        );
        assertEq(feeAdapter.lastAmount(), input.amount, "expected feeAdapter.lastAmount() to equal input.amount");

        (uint256 storedFee, uint256 storedDeadline, bytes memory storedSig) = feeAdapter.lastFeeParams();
        assertEq(storedFee, input.fee, "expected storedFee to equal input.fee");
        assertEq(storedDeadline, input.deadline, "expected storedDeadline to equal input.deadline");
        assertEq(
            keccak256(storedSig), keccak256(input.sig), "expected keccak256(storedSig) to equal keccak256(input.sig)"
        );
    }

    function test_fuzz_sendMsg_success_noExcess(
        uint96 amountRaw,
        uint96 feeRaw,
        uint24 maxFeeRaw,
        uint48 ttl,
        bytes calldata data,
        bytes calldata sig,
        uint256 deadline
    ) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 dataLength = bound(data.length, 0, 64);
        bytes memory boundedData = new bytes(dataLength);
        for (uint256 i; i < dataLength; ++i) {
            boundedData[i] = data[i];
        }

        uint256 sigLength = bound(sig.length, 0, 64);
        bytes memory boundedSig = new bytes(sigLength);
        for (uint256 i; i < sigLength; ++i) {
            boundedSig[i] = sig[i];
        }

        IntentInput memory input = _defaultInput();
        input.amount = bound(amountRaw, 1, 1e18);
        input.fee = bound(feeRaw, 0, input.amount / 2);
        input.maxFee = uint24(bound(uint256(maxFeeRaw), 0, input.amount / 10));
        input.ttl = ttl;
        input.data = boundedData;
        input.deadline = deadline;
        input.sig = boundedSig;

        (bytes memory message, uint32 dstChainId) = _buildMessage(1, input);

        uint256 extractedAmount = input.amount + input.fee;

        token.mint(rebalancer, extractedAmount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), extractedAmount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, true);
        emit EverclearBridge.MsgSent(dstChainId, market, input.amount, feeAdapter.nextId());

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(extractedAmount, market, dstChainId, address(token), message, "");
        vm.stopPrank();

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(market), 0, "expected token.balanceOf(market) to equal 0");
        assertEq(
            token.balanceOf(address(bridge)),
            input.amount + input.fee,
            "expected token.balanceOf(address(bridge)) to equal input.amount + input.fee"
        );
        assertEq(
            token.allowance(address(bridge), address(feeAdapter)),
            input.amount + input.fee,
            "expected token.allowance(address(bridge), address(feeAdapter)) to equal input.amount + input.fee"
        );
        assertEq(feeAdapter.callCount(), 1, "expected feeAdapter.callCount() to equal 1");
        assertEq(
            feeAdapter.lastDestinations(0), dstChainId, "expected feeAdapter.lastDestinations(0) to equal dstChainId"
        );
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

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
