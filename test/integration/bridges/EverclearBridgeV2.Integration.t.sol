// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;


import "forge-std/Test.sol";

import { IFeeAdapterV2, EverclearBridgeV2 } from "src/rebalancer/bridges/EverclearBridgeV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//temp tests - 
contract EverclearBridgeV2Integration is Test {
    // Linea mainnet addresses
    address constant FEE_ADAPTER = 0xAa7ee09f745a3c5De329EB0CD67878Ba87B70Ffe;
    address constant USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
    address constant MARKET = 0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b;
    uint32 constant DST_CHAIN_ID = 8453;
    uint256 constant AMOUNT = 14790000; 
    uint256 constant FEE = 210000;
    uint256 constant EXTRACTED_AMOUNT = 15000000; 
    bytes constant TEST_MESSAGE = hex"ceb6341c00000000000000000000000000000000000000000000000000000000000001200000000000000000000000001eea258b505cd6381171c1075ec6934f8d0faf3b000000000000000000000000176211869ca2b568f2a7d4ee941e073a821ee1ff000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000000000000e1ad700000000000000000000000000000000000000000000000000000000000e19bdc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000210500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033450000000000000000000000000000000000000000000000000000000006930cab600000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041658c3d906d5297916934308b36e9c189b80d5900330232d4e7a33ffe256ea32d6d2d330e7b30d941ffb0368471ceb5dfca2c614a9ba3c6a8bdb07598405064a21b00000000000000000000000000000000000000000000000000000000000000";
    
    EverclearBridgeV2 public bridge;
    address constant roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
    address constant rebalancer = 0x43090Bd0499936f0F66DaCd870aa84fFdc92EDB1;

    uint256 lineaFork;
    function setUp() public {
        string memory lineaRpc = vm.envString("LINEA_RPC_URL");
        lineaFork = vm.createSelectFork(lineaRpc);

        bridge = new EverclearBridgeV2(roles, FEE_ADAPTER);

        vm.mockCall(
            roles,
            abi.encodeWithSignature("isAllowedFor(address,bytes32)"),
            abi.encode(true)
        );
    }

    function test_DecodeMessage() public pure {
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint i = 4; i < TEST_MESSAGE.length; i++) {
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
        ) = abi.decode(
            data,
            (uint32[], bytes32, address, bytes32, uint256, uint256, uint48, bytes)
        );
        
        console.log("Destinations length:", destinations.length);
        console.log("Destination chain:", destinations[0]);
        console.log("Receiver:", vm.toString(receiver));
        console.log("Input asset:", inputAsset);
        console.log("Output asset:", vm.toString(outputAsset));
        console.log("Amount:", amount);
        console.log("Amount out min:", amountOutMin);
        console.log("TTL:", ttl);
        console.log("Extra data length:", extraData.length);
        
        assertEq(destinations.length, 1);
        assertEq(destinations[0], 8453);
        assertEq(inputAsset, USDC);
        assertEq(amount, 14790000);
        assertEq(amountOutMin, 14785500);
    }

     function test_ExtractFeeParams() public pure {
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint i = 4; i < TEST_MESSAGE.length; i++) {
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
        
        assertEq(fee, 210000);
        assertEq(deadline, 1764805302);
    }


   function test_CallFeeAdapter() public {
        // Decode the message into intent parameters
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
        _callNewIntent(
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

    // skipping for now because we would need to call the API with `surl`
    // otherwise the deadline is in the past and this fails with 
    // $ cast 4byte 0x634f518f -> FeeAdapter_InvalidDeadline()
    function test_SendMsg_Success() public {
        vm.skip(true);
        console.log("\n=== Test: sendMsg Success ===");
        
        // Give rebalancer USDC
        deal(USDC, rebalancer, EXTRACTED_AMOUNT);
        
        // Record initial balances
        uint256 rebalancerBalanceBefore = IERC20(USDC).balanceOf(rebalancer);
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
        
        vm.startPrank(rebalancer);
        IERC20(USDC).approve(address(bridge), EXTRACTED_AMOUNT);
        
        bridge.sendMsg(
            EXTRACTED_AMOUNT,
            MARKET,
            DST_CHAIN_ID,
            USDC,
            TEST_MESSAGE,
            ""
        );
        vm.stopPrank();
        
        // Record final balances
        uint256 rebalancerBalanceAfter = IERC20(USDC).balanceOf(rebalancer);
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
            "Rebalancer should spend exact extracted amount"
        );
        
        assertEq(
            marketBalanceAfter - marketBalanceBefore,
            expectedReturn,
            "Market should receive excess"
        );
        
        assertEq(
            bridgeBalanceAfter,
            bridgeBalanceBefore,
            "Bridge should not hold funds"
        );
    }
    
    function _decodeIntentParams() internal pure returns (
        uint32[] memory destinations,
        bytes32 receiver,
        address inputAsset,
        bytes32 outputAsset,
        uint256 amount,
        uint256 amountOutMin,
        uint48 ttl,
        bytes memory extraData
    ) {
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint i = 4; i < TEST_MESSAGE.length; i++) {
            data[i - 4] = TEST_MESSAGE[i];
        }
        
        return abi.decode(
            data,
            (uint32[], bytes32, address, bytes32, uint256, uint256, uint48, bytes)
        );
    }
    
    function _extractFeeParamsFromMessage() internal pure returns (IFeeAdapterV2.FeeParams memory) {
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint i = 4; i < TEST_MESSAGE.length; i++) {
            data[i - 4] = TEST_MESSAGE[i];
        }
        
        uint256 feeParamsOffset;
        assembly {
            feeParamsOffset := mload(add(data, add(32, 0x100)))
        }
        
        (uint256 fee, uint256 deadline) = _readFeeAndDeadline(data, feeParamsOffset);
        bytes memory sig = _readSignature(data, feeParamsOffset);
        
        return IFeeAdapterV2.FeeParams({
            fee: fee,
            deadline: deadline,
            sig: sig
        });
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
    
    function _readSignature(bytes memory data, uint256 feeParamsOffset) 
        internal 
        pure 
        returns (bytes memory sig) 
    {
        uint256 sigOffset;
        assembly {
            sigOffset := mload(add(data, add(96, feeParamsOffset)))
        }
        
        uint256 sigLen;
        assembly {
            sigLen := mload(add(data, add(add(32, feeParamsOffset), sigOffset)))
        }
        
        sig = new bytes(sigLen);
        for (uint i = 0; i < sigLen; i++) {
            sig[i] = data[feeParamsOffset + sigOffset + 32 + i];
        }
    }
    
    function _setupUSDCApproval(uint256 amount) internal {
        deal(USDC, address(this), amount);
        
        (bool success, ) = USDC.call(
            abi.encodeWithSignature("approve(address,uint256)", FEE_ADAPTER, amount)
        );
        require(success);
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