// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

import {EverclearBridgeV2, IFeeAdapterV2} from "src/rebalancer/bridges/EverclearBridgeV2.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

/// @notice Fork tests for EverclearBridgeV2.
contract EverclearBridgeV2ForkTest is BaseForkTest {
    // Linea mainnet addresses
    address internal constant FEE_ADAPTER = 0xAa7ee09f745a3c5De329EB0CD67878Ba87B70Ffe;
    address internal constant USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
    address internal constant MARKET = 0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b;
    uint32 internal constant DST_CHAIN_ID = 8453;
    uint256 internal constant AMOUNT = 14790000;
    uint256 internal constant FEE = 210000;
    uint256 internal constant EXTRACTED_AMOUNT = 15000000;
    bytes internal constant TEST_MESSAGE =
        hex"ceb6341c00000000000000000000000000000000000000000000000000000000000001200000000000000000000000001eea258b505cd6381171c1075ec6934f8d0faf3b000000000000000000000000176211869ca2b568f2a7d4ee941e073a821ee1ff000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000000000000e1ad700000000000000000000000000000000000000000000000000000000000e19bdc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000210500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033450000000000000000000000000000000000000000000000000000000006930cab600000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041658c3d906d5297916934308b36e9c189b80d5900330232d4e7a33ffe256ea32d6d2d330e7b30d941ffb0368471ceb5dfca2c614a9ba3c6a8bdb07598405064a21b00000000000000000000000000000000000000000000000000000000000000";

    address internal constant ROLES = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
    address internal constant REBALANCER = 0x43090Bd0499936f0F66DaCd870aa84fFdc92EDB1;

    EverclearBridgeV2 public bridge;

    function setUp() public override {
        super.setUp();
        _selectLineaFork();

        bridge = new EverclearBridgeV2(ROLES, FEE_ADAPTER);

        vm.mockCall(ROLES, abi.encodeWithSignature("isAllowedFor(address,bytes32)"), abi.encode(true));
    }

    ////////////////////////////////////////////////////////////
    //                     DecodeMessage                      //
    ////////////////////////////////////////////////////////////

    function test_fork_decodeMessage_success() public pure {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint256 i = 4; i < TEST_MESSAGE.length; i++) {
            data[i - 4] = TEST_MESSAGE[i];
        }

        (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint256 amountOutMin,
            uint48 ttl,
            bytes memory extraData
            // ~~~~~~~~~~ Call ~~~~~~~~~~
        ) = abi.decode(data, (uint32[], bytes32, address, bytes32, uint256, uint256, uint48, bytes));

        console.log("Destinations length:", destinations.length);
        console.log("Destination chain:", destinations[0]);
        console.log("Receiver:", vm.toString(receiver));
        console.log("Input asset:", inputAsset);
        console.log("Output asset:", vm.toString(outputAsset));
        console.log("Amount:", amount);
        console.log("Amount out min:", amountOutMin);
        console.log("TTL:", ttl);
        console.log("Extra data length:", extraData.length);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(destinations.length, 1, "destinations array should have one entry");
        assertEq(destinations[0], 8453, "destination chain id should be Base");
        assertEq(inputAsset, USDC, "input asset is not USDC");
        assertEq(amount, 14790000, "amount does not match expected");
        assertEq(amountOutMin, 14785500, "min output amount does not match expected");
    }

    function test_fork_decodeMessage_success_variant2() public pure {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint256 i = 4; i < TEST_MESSAGE.length; i++) {
            data[i - 4] = TEST_MESSAGE[i];
        }

        uint256 feeParamsOffset;
        assembly {
            feeParamsOffset := mload(add(data, add(32, 0x100)))
        }

        console.log("FeeParams offset:", feeParamsOffset);

        uint256 fee;
        assembly {
            fee := mload(add(data, add(32, feeParamsOffset)))
        }

        uint256 deadline;
        assembly {
            deadline := mload(add(data, add(64, feeParamsOffset)))
        }

        console.log("Fee:", fee);
        console.log("Deadline:", deadline);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(fee, 210000, "fee does not match expected");
        assertEq(deadline, 1764805302, "deadline does not match expected");
    }

    ////////////////////////////////////////////////////////////
    //                     CallNewIntent                      //
    ////////////////////////////////////////////////////////////

    function test_fork_callNewIntent_success() public {
        // Decode the message into intent parameters
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint256 amountOutMin,
            uint48 ttl,
            bytes memory extraData
        ) = _decodeIntentParams();

        // Extract fee parameters from the message
        IFeeAdapterV2.FeeParams memory feeParams = _extractFeeParamsFromMessage();

        console.log("Signature length:", feeParams.sig.length);
        console.logBytes(feeParams.sig);

        // Setup USDC approval
        _setupUSDCApproval(amount + feeParams.fee);

        console.log("=== Calling Fee Adapter ===");
        console.log("Amount + Fee:", amount + feeParams.fee);

        // Call the fee adapter
        _callNewIntent(destinations, receiver, inputAsset, outputAsset, amount, amountOutMin, ttl, extraData, feeParams);
    }

    // skipping for now because we would need to call the API with `surl`
    // otherwise the deadline is in the past and this fails with
    // $ cast 4byte 0x634f518f -> FeeAdapter_InvalidDeadline()

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_fork_sendMsg_success() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        console.log("\n=== Test: sendMsg Success ===");

        // Give rebalancer USDC
        deal(USDC, REBALANCER, EXTRACTED_AMOUNT);

        // Record initial balances
        uint256 rebalancerBalanceBefore = IERC20(USDC).balanceOf(REBALANCER);
        uint256 marketBalanceBefore = IERC20(USDC).balanceOf(MARKET);
        uint256 bridgeBalanceBefore = IERC20(USDC).balanceOf(address(bridge));
        uint256 feeAdapterBalanceBefore = IERC20(USDC).balanceOf(FEE_ADAPTER);

        console.log("\nInitial Balances:");
        console.log("  Rebalancer:", rebalancerBalanceBefore);
        console.log("  Market:", marketBalanceBefore);
        console.log("  Bridge:", bridgeBalanceBefore);
        console.log("  Fee Adapter:", feeAdapterBalanceBefore);

        uint256 expectedReturn = EXTRACTED_AMOUNT - AMOUNT - FEE;
        console.log("\nExpected excess return to market:", expectedReturn);

        bytes32 intentId = keccak256("everclear-intent");
        IFeeAdapterV2.Intent memory intentResult = IFeeAdapterV2.Intent({
            initiator: bytes32(0),
            receiver: bytes32(0),
            inputAsset: bytes32(0),
            outputAsset: bytes32(0),
            origin: 0,
            nonce: 0,
            timestamp: 0,
            ttl: 0,
            amount: 0,
            amountOutMin: 0,
            destinations: new uint32[](0),
            data: bytes("")
        });
        bytes memory intentCallData = abi.encodeWithSelector(
            IFeeAdapterV2.newIntent.selector,
            new uint32[](1),
            bytes32(uint256(uint160(MARKET))),
            USDC,
            bytes32(uint256(uint160(USDC))),
            AMOUNT,
            AMOUNT - FEE,
            uint48(0),
            bytes(""),
            IFeeAdapterV2.FeeParams({fee: FEE, deadline: 0, sig: ""})
        );

        {
            (
                uint32[] memory destinations,
                bytes32 receiver,
                address inputAsset,
                bytes32 outputAsset,
                uint256 amount,
                uint256 amountOutMin,
                uint48 ttl,
                bytes memory extraData
            ) = _decodeIntentParams();
            IFeeAdapterV2.FeeParams memory feeParams = _extractFeeParamsFromMessage();

            intentResult = IFeeAdapterV2.Intent({
                initiator: bytes32(0),
                receiver: receiver,
                inputAsset: bytes32(uint256(uint160(inputAsset))),
                outputAsset: outputAsset,
                origin: 0,
                nonce: 0,
                timestamp: 0,
                ttl: ttl,
                amount: amount,
                amountOutMin: amountOutMin,
                destinations: destinations,
                data: extraData
            });

            intentCallData = abi.encodeWithSelector(
                IFeeAdapterV2.newIntent.selector,
                destinations,
                receiver,
                inputAsset,
                outputAsset,
                amount,
                amountOutMin,
                ttl,
                extraData,
                feeParams
            );
        }

        vm.mockCall(FEE_ADAPTER, intentCallData, abi.encode(intentId, intentResult));

        vm.startPrank(REBALANCER);
        IERC20(USDC).approve(address(bridge), EXTRACTED_AMOUNT);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(EXTRACTED_AMOUNT, MARKET, DST_CHAIN_ID, USDC, TEST_MESSAGE, "");
        vm.stopPrank();

        // Record final balances
        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 rebalancerBalanceAfter = IERC20(USDC).balanceOf(REBALANCER);
        uint256 marketBalanceAfter = IERC20(USDC).balanceOf(MARKET);
        uint256 bridgeBalanceAfter = IERC20(USDC).balanceOf(address(bridge));
        uint256 feeAdapterBalanceAfter = IERC20(USDC).balanceOf(FEE_ADAPTER);

        console.log("\nFinal Balances:");
        console.log("  Rebalancer:", rebalancerBalanceAfter);
        console.log("  Market:", marketBalanceAfter);
        console.log("  Bridge:", bridgeBalanceAfter);
        console.log("  Fee Adapter:", feeAdapterBalanceAfter);

        console.log("\nBalance Changes:");
        console.log("  Rebalancer spent:", rebalancerBalanceBefore - rebalancerBalanceAfter);
        console.log("  Market received:", marketBalanceAfter - marketBalanceBefore);
        console.log("  Fee Adapter received:", feeAdapterBalanceAfter - feeAdapterBalanceBefore);

        // Assertions
        assertEq(
            rebalancerBalanceBefore - rebalancerBalanceAfter,
            EXTRACTED_AMOUNT,
            "rebalancer should spend the extracted amount"
        );

        assertEq(marketBalanceAfter - marketBalanceBefore, expectedReturn, "market should receive the excess amount");

        uint256 expectedBridgeBalance = bridgeBalanceBefore + EXTRACTED_AMOUNT - expectedReturn;
        assertEq(bridgeBalanceAfter, expectedBridgeBalance, "bridge should retain the transferred funds");
    }

    function test_fork_sendMsg_revertsWith_Everclear_TokenMismatch() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(EXTRACTED_AMOUNT, MARKET, DST_CHAIN_ID, address(0xdead), TEST_MESSAGE, "");
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenExtractedTooSmall() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 extractedAmount = AMOUNT - 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(extractedAmount, MARKET, DST_CHAIN_ID, USDC, TEST_MESSAGE, "");
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenAmountZero() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,,
            uint256 amountOutMin,
            uint48 ttl,
            bytes memory extraData
        ) = _decodeIntentParams();
        IFeeAdapterV2.FeeParams memory feeParams = _extractFeeParamsFromMessage();

        bytes memory message = _encodeIntentParams(
            destinations, receiver, inputAsset, outputAsset, 0, amountOutMin, ttl, extraData, feeParams
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(1, MARKET, DST_CHAIN_ID, USDC, message, "");
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_AddressNotValid_whenReceiverMismatch() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(EXTRACTED_AMOUNT, users.bob, DST_CHAIN_ID, USDC, TEST_MESSAGE, "");
    }

    function test_fork_sendMsg_revertsWith_Everclear_DestinationsLengthMismatch() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (
            ,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint256 amountOutMin,
            uint48 ttl,
            bytes memory extraData
        ) = _decodeIntentParams();
        IFeeAdapterV2.FeeParams memory feeParams = _extractFeeParamsFromMessage();

        uint32[] memory destinations = new uint32[](2);
        destinations[0] = DST_CHAIN_ID;
        destinations[1] = DST_CHAIN_ID;

        bytes memory message = _encodeIntentParams(
            destinations, receiver, inputAsset, outputAsset, amount, amountOutMin, ttl, extraData, feeParams
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_DestinationsLengthMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(EXTRACTED_AMOUNT, MARKET, DST_CHAIN_ID, USDC, message, "");
    }

    function test_fork_sendMsg_revertsWith_Everclear_DestinationNotValid() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (
            ,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint256 amountOutMin,
            uint48 ttl,
            bytes memory extraData
        ) = _decodeIntentParams();
        IFeeAdapterV2.FeeParams memory feeParams = _extractFeeParamsFromMessage();

        uint32[] memory destinations = new uint32[](1);
        destinations[0] = DST_CHAIN_ID + 1;

        bytes memory message = _encodeIntentParams(
            destinations, receiver, inputAsset, outputAsset, amount, amountOutMin, ttl, extraData, feeParams
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_DestinationNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(EXTRACTED_AMOUNT, MARKET, DST_CHAIN_ID, USDC, message, "");
    }

    function test_fork_sendMsg_revertsWith_Everclear_MaxSlippageExceeded() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,,
            uint48 ttl,
            bytes memory extraData
        ) = _decodeIntentParams();
        IFeeAdapterV2.FeeParams memory feeParams = _extractFeeParamsFromMessage();

        uint256 amountOutMin = amount * 9 / 10 - 1;
        bytes memory message = _encodeIntentParams(
            destinations, receiver, inputAsset, outputAsset, amount, amountOutMin, ttl, extraData, feeParams
        );

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_MaxSlippageExceeded.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(EXTRACTED_AMOUNT, MARKET, DST_CHAIN_ID, USDC, message, "");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _decodeIntentParams()
        internal
        pure
        returns (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint256 amountOutMin,
            uint48 ttl,
            bytes memory extraData
        )
    {
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint256 i = 4; i < TEST_MESSAGE.length; i++) {
            data[i - 4] = TEST_MESSAGE[i];
        }

        return abi.decode(data, (uint32[], bytes32, address, bytes32, uint256, uint256, uint48, bytes));
    }

    function _encodeIntentParams(
        uint32[] memory destinations,
        bytes32 receiver,
        address inputAsset,
        bytes32 outputAsset,
        uint256 amount,
        uint256 amountOutMin,
        uint48 ttl,
        bytes memory extraData,
        IFeeAdapterV2.FeeParams memory feeParams
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IFeeAdapterV2.newIntent.selector,
            destinations,
            receiver,
            inputAsset,
            outputAsset,
            amount,
            amountOutMin,
            ttl,
            extraData,
            feeParams
        );
    }

    function _extractFeeParamsFromMessage() internal pure returns (IFeeAdapterV2.FeeParams memory) {
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint256 i = 4; i < TEST_MESSAGE.length; i++) {
            data[i - 4] = TEST_MESSAGE[i];
        }

        uint256 feeParamsOffset;
        assembly {
            feeParamsOffset := mload(add(data, add(32, 0x100)))
        }

        (uint256 fee, uint256 deadline) = _readFeeAndDeadline(data, feeParamsOffset);
        bytes memory sig = _readSignature(data, feeParamsOffset);

        return IFeeAdapterV2.FeeParams({fee: fee, deadline: deadline, sig: sig});
    }

    function _readFeeAndDeadline(bytes memory data, uint256 feeParamsOffset)
        internal
        pure
        returns (uint256 fee, uint256 deadline)
    {
        assembly {
            fee := mload(add(data, add(32, feeParamsOffset)))
            deadline := mload(add(data, add(64, feeParamsOffset)))
        }
    }

    function _readSignature(bytes memory data, uint256 feeParamsOffset) internal pure returns (bytes memory sig) {
        uint256 sigOffset;
        assembly {
            sigOffset := mload(add(data, add(96, feeParamsOffset)))
        }

        uint256 sigLen;
        assembly {
            sigLen := mload(add(data, add(add(32, feeParamsOffset), sigOffset)))
        }

        sig = new bytes(sigLen);
        for (uint256 i = 0; i < sigLen; i++) {
            sig[i] = data[feeParamsOffset + sigOffset + 32 + i];
        }
    }

    function _setupUSDCApproval(uint256 amount) internal {
        deal(USDC, address(this), amount);

        (bool success,) = USDC.call(abi.encodeWithSignature("approve(address,uint256)", FEE_ADAPTER, amount));
        require(success, "Failed to approve USDC");
    }

    function _callNewIntent(
        uint32[] memory destinations,
        bytes32 receiver,
        address inputAsset,
        bytes32 outputAsset,
        uint256 amount,
        uint256 amountOutMin,
        uint48 ttl,
        bytes memory extraData,
        IFeeAdapterV2.FeeParams memory feeParams
    ) internal {
        (bool callSuccess, bytes memory returnData) = FEE_ADAPTER.call{value: 0}(
            abi.encodeWithSelector(
                IFeeAdapterV2.newIntent.selector,
                destinations,
                receiver,
                inputAsset,
                outputAsset,
                amount,
                amountOutMin,
                ttl,
                extraData,
                feeParams
            )
        );

        if (!callSuccess) {
            console.log("failed");
        } else {
            console.log("works");
            console.logBytes(returnData);
        }
    }
}
