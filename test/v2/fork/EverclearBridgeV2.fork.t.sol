// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {EverclearBridgeV2, IFeeAdapterV2} from "src/rebalancer/bridges/EverclearBridgeV2.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {Vm} from "forge-std/Vm.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

interface IRolesRegistry {
    function REBALANCER() external view returns (bytes32);
    function isAllowedFor(address contractAddress, bytes32 roleIdentifier) external view returns (bool);
    function allowFor(address contractAddress, bytes32 roleIdentifier, bool allowed) external;
    function owner() external view returns (address);
}

/// @notice Fork tests for EverclearBridgeV2.
contract EverclearBridgeV2ForkTest is BaseForkTest {
    // The BaseForkTest pinned block predates the deployment of the Everclear fee adapter on Linea.
    // Use a later pinned block for this suite so we can run against the real adapter (no mocks).
    // 2025-12-03 on Linea: chosen to be before the message deadline embedded in TEST_MESSAGE.
    uint256 internal constant LINEA_EVERCLEAR_FORK_BLOCK = 26_303_964;

    // Linea mainnet addresses
    address internal constant FEE_ADAPTER = 0xAa7ee09f745a3c5De329EB0CD67878Ba87B70Ffe;
    address internal constant USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
    address internal constant MARKET = 0x1eEa258B505cd6381171c1075EC6934F8D0Faf3b;

    address internal constant ROLES = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
    address internal constant REBALANCER = 0x43090Bd0499936f0F66DaCd870aa84fFdc92EDB1;

    uint32 internal constant DST_CHAIN_ID = 8453;
    uint256 internal constant AMOUNT = 14_790_000;
    uint256 internal constant AMOUNT_OUT_MIN = 14_785_500;
    uint256 internal constant FEE = 210_000;
    uint256 internal constant EXTRACTED_AMOUNT = 15_000_000;

    bytes internal constant TEST_MESSAGE =
        hex"ceb6341c00000000000000000000000000000000000000000000000000000000000001200000000000000000000000001eea258b505cd6381171c1075ec6934f8d0faf3b000000000000000000000000176211869ca2b568f2a7d4ee941e073a821ee1ff000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda029130000000000000000000000000000000000000000000000000000000000e1ad700000000000000000000000000000000000000000000000000000000000e19bdc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000210500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033450000000000000000000000000000000000000000000000000000000006930cab600000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041658c3d906d5297916934308b36e9c189b80d5900330232d4e7a33ffe256ea32d6d2d330e7b30d941ffb0368471ceb5dfca2c614a9ba3c6a8bdb07598405064a21b00000000000000000000000000000000000000000000000000000000000000";

    EverclearBridgeV2 public bridge;

    function setUp() public override {
        super.setUp();
        lineaFork = vm.createFork(vm.envString("LINEA_RPC_URL"), LINEA_EVERCLEAR_FORK_BLOCK);
        _selectLineaFork();

        // This suite is pinned to a later block for Everclear availability; ensure the on-chain
        // rebalancer is authorized on this fork snapshot (no mocks, real Roles contract).
        IRolesRegistry roles = IRolesRegistry(ROLES);
        bytes32 rebalancerRole = roles.REBALANCER();
        if (!roles.isAllowedFor(REBALANCER, rebalancerRole)) {
            vm.prank(roles.owner());
            roles.allowFor(REBALANCER, rebalancerRole, true);
        }
        assertTrue(roles.isAllowedFor(REBALANCER, rebalancerRole), "REBALANCER is not allowed in Roles");

        bridge = new EverclearBridgeV2(ROLES, FEE_ADAPTER);
    }

    ////////////////////////////////////////////////////////////
    //                     DecodeMessage                      //
    ////////////////////////////////////////////////////////////

    function test_fork_decodeMessage_success() public pure {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory data = new bytes(TEST_MESSAGE.length - 4);
        for (uint256 i = 4; i < TEST_MESSAGE.length; ++i) {
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
        ) = abi.decode(data, (uint32[], bytes32, address, bytes32, uint256, uint256, uint48, bytes));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(destinations.length, 1, "destinations array should have one entry");
        assertEq(destinations[0], DST_CHAIN_ID, "destination chain id is not Base");
        assertEq(receiver, bytes32(uint256(uint160(MARKET))), "receiver is not the destination market");
        assertEq(inputAsset, USDC, "input asset is not USDC");
        assertEq(amount, AMOUNT, "decoded amount does not match expected");
        assertEq(amountOutMin, AMOUNT_OUT_MIN, "decoded amountOutMin does not match expected");
        assertEq(ttl, 0, "decoded ttl does not match expected");
        assertEq(extraData.length, 0, "expected empty extraData");

        // Silence unused local warning for outputAsset.
        outputAsset;
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_fork_sendMsg_success() public {
        _selectLineaFork();

        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 rebalancerBalanceBefore = IERC20(USDC).balanceOf(REBALANCER);
        uint256 bridgeBalanceBefore = IERC20(USDC).balanceOf(address(bridge));
        uint256 marketBalanceBefore = IERC20(USDC).balanceOf(MARKET);

        assertGe(rebalancerBalanceBefore, EXTRACTED_AMOUNT, "rebalancer does not have enough USDC for sendMsg");
        assertEq(bridgeBalanceBefore, 0, "bridge should start with 0 USDC");

        vm.prank(REBALANCER);
        IERC20(USDC).approve(address(bridge), EXTRACTED_AMOUNT);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.recordLogs();

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(REBALANCER);
        bridge.sendMsg(EXTRACTED_AMOUNT, MARKET, DST_CHAIN_ID, USDC, TEST_MESSAGE, "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 rebalancerBalanceAfter = IERC20(USDC).balanceOf(REBALANCER);
        uint256 bridgeBalanceAfter = IERC20(USDC).balanceOf(address(bridge));
        uint256 marketBalanceAfter = IERC20(USDC).balanceOf(MARKET);

        assertEq(
            rebalancerBalanceBefore - rebalancerBalanceAfter,
            EXTRACTED_AMOUNT,
            "rebalancer did not spend the extracted amount"
        );

        assertEq(marketBalanceAfter, marketBalanceBefore, "market balance changed unexpectedly");
        assertEq(bridgeBalanceAfter, 0, "bridge retained USDC after sendMsg");

        (uint256 dstChainId, address loggedMarket, uint256 amountLD, bytes32 id) = _findMsgSent();
        assertEq(dstChainId, DST_CHAIN_ID, "dstChainId in MsgSent is not Base chain id");
        assertEq(loggedMarket, MARKET, "market in MsgSent is not the expected market");
        assertEq(amountLD, AMOUNT, "amountLD in MsgSent is not the expected amount");
        assertTrue(id != bytes32(0), "MsgSent id is zero");
    }

    function test_fork_sendMsg_revertsWith_Everclear_TokenMismatch() public {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(EverclearBridgeV2.Everclear_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(REBALANCER);
        bridge.sendMsg(EXTRACTED_AMOUNT, MARKET, DST_CHAIN_ID, address(0xdead), TEST_MESSAGE, "");
    }

    function test_fork_sendMsg_revertsWith_BaseBridge_AmountMismatch_whenExtractedTooSmall() public {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 extractedAmount = AMOUNT - 1;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(REBALANCER);
        bridge.sendMsg(extractedAmount, MARKET, DST_CHAIN_ID, USDC, TEST_MESSAGE, "");
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
        for (uint256 i = 4; i < TEST_MESSAGE.length; ++i) {
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
        for (uint256 i = 4; i < TEST_MESSAGE.length; ++i) {
            data[i - 4] = TEST_MESSAGE[i];
        }

        uint256 feeParamsOffset;
        assembly {
            feeParamsOffset := mload(add(data, add(32, 0x100)))
        }

        uint256 fee;
        uint256 deadline;
        assembly {
            fee := mload(add(data, add(32, feeParamsOffset)))
            deadline := mload(add(data, add(64, feeParamsOffset)))
        }

        uint256 sigOffset;
        assembly {
            sigOffset := mload(add(data, add(96, feeParamsOffset)))
        }

        uint256 sigLen;
        assembly {
            sigLen := mload(add(data, add(add(32, feeParamsOffset), sigOffset)))
        }

        bytes memory sig = new bytes(sigLen);
        for (uint256 i; i < sigLen; ++i) {
            sig[i] = data[feeParamsOffset + sigOffset + 32 + i];
        }

        return IFeeAdapterV2.FeeParams({fee: fee, deadline: deadline, sig: sig});
    }

    function _findMsgSent() internal returns (uint256 dstChainId, address market, uint256 amountLD, bytes32 id) {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 sig = keccak256("MsgSent(uint256,address,uint256,bytes32)");

        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory e = entries[i];
            if (e.emitter != address(bridge)) continue;
            if (e.topics.length < 3 || e.topics[0] != sig) continue;

            dstChainId = uint256(e.topics[1]);
            market = address(uint160(uint256(e.topics[2])));
            (amountLD, id) = abi.decode(e.data, (uint256, bytes32));
            return (dstChainId, market, amountLD, id);
        }

        revert("MsgSent event not found");
    }
}
