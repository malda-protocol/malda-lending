// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {IRebalancer, IRebalanceMarket} from "src/interfaces/IRebalancer.sol";
import {IFeeAdapter} from "src/interfaces/external/everclear/IFeeAdapter.sol";
import {Rebalancer_Unit_Shared} from "../shared/Rebalancer_Unit_Shared.t.sol";
import {BytesLib} from "src/libraries/BytesLib.sol";

import "forge-std/console2.sol";

contract Rebalancer_methods is Rebalancer_Unit_Shared {
    function setUp() public override {
        super.setUp();

        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        rebalancer.setMaxTransferSize(0, address(weth), type(uint256).max);
        rebalancer.setMaxTransferSize(1, address(weth), type(uint256).max);
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), false);
    }

    modifier givenSenderDoesNotHaveGUARDIAN_BRIDGERole() {
        //does nothing; for readability only
        _;
    }


    function testDecodeFull() external {
        bytes memory msge = hex"0000000000000000000000000000000000000000000000000000000000000140000000000000000000000000b819a871d20913839c37f316dc914b0570bfc0ee000000000000000000000000176211869ca2b568f2a7d4ee941e073a821ee1ff000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda0291300000000000000000000000000000000000000000000000000000000004908e000000000000000000000000000000000000000000000000000000000000f42400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000001a00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000021050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000342600000000000000000000000000000000000000000000000000000000068d57c3800000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000041640266288fc38585602e100c62f4bdad09957a74b0cd68a70860adcbc2119d02117b14da483dbc26ba437f2da24a22d87a4f8bad9d8183513bbf59af8535ff0a1c00000000000000000000000000000000000000000000000000000000000000"; // your full calldata without selector

    (
            uint32[] memory destinations,
            bytes32 receiver,
            address inputAsset,
            bytes32 outputAsset,
            uint256 amount,
            uint256 maxFee,
            uint256 ttl,
            bytes memory data
        ) = abi.decode(
            msge,
            (uint32[], bytes32, address, bytes32, uint256, uint256, uint256, bytes)
        );

        (uint256 fee, uint256 deadline, bytes memory sig) = _extractFeeParams(msge);

        console2.log("Fee:", fee);
        console2.log("Deadline:", deadline);
    }
    function _extractFeeParams(bytes memory msge) private view returns (uint256 fee, uint256 deadline, bytes memory sig) {
        uint256 feeParamsOffset = BytesLib.toUint256(msge, 0x120);
        uint256 feeParamsPtr = feeParamsOffset; // absolute inside msge

        fee = BytesLib.toUint256(msge, feeParamsPtr);
        deadline = BytesLib.toUint256(msge, feeParamsPtr + 32);

        uint256 sigOffset = BytesLib.toUint256(msge, feeParamsOffset + 64);
        uint256 sigLen = BytesLib.toUint256(msge, feeParamsOffset + sigOffset);
        sig = BytesLib.slice(msge, feeParamsOffset + sigOffset + 32, sigLen);

    }


    function test_WhenSetWhitelistedBridgeStatusIsCalledWithTrue() external givenSenderDoesNotHaveGUARDIAN_BRIDGERole {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        // it should not set a bridge and revert with Rebalancer_NotAuthorized
    }

    function test_WhenSetWhitelistedBridgeStatusIsCalledWithFalse()
        external
        givenSenderDoesNotHaveGUARDIAN_BRIDGERole
    {
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        // it should not set a bridge and revert with Rebalancer_NotAuthorized
    }

    modifier givenSenderHasRoleGUARDIAN_BRIDGE() {
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        _;
    }

    function test_WhenSetWhitelistedBridgeStatusIsCalledToWhitelist() external givenSenderHasRoleGUARDIAN_BRIDGE {
        // it should whitelist a bridge
        vm.expectEmit(true, true, true, true);
        emit IRebalancer.BridgeWhitelistedStatusUpdated(address(bridgeMock), true);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
    }

    function test_WhenIsBridgeWhitelistedIsCalled() external givenSenderHasRoleGUARDIAN_BRIDGE {
        // it should return true
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        bool isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));
        assertTrue(isWhitelisted);
    }

    function test_WhenSetWhitelistedBridgeStatusIsCalledToRemoveFromWhitelist()
        external
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should remove bridge from whitelist mapping
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        bool isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));
        assertTrue(isWhitelisted);
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), false);
        isWhitelisted = rebalancer.isBridgeWhitelisted(address(bridgeMock));
        assertFalse(isWhitelisted);
    }

    modifier givenSendMsgIsCalledWithWrongParameters() {
        _;
    }

    function test_WhenSenderDoesNotHaveREBALANCER_EOARole() external givenSendMsgIsCalledWithWrongParameters {
        // it should revert with Rebalancer_NotAuthorized
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});
        vm.expectRevert(IRebalancer.Rebalancer_NotAuthorized.selector);
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    function test_WhenBridgeIsNotWhitelisted() external givenSendMsgIsCalledWithWrongParameters {
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});
        vm.expectRevert(IRebalancer.Rebalancer_BridgeNotWhitelisted.selector);
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
        // it should revert with Rebalancer_BridgeNotWhitelisted
    }

    function test_WhenUnderlyingIsNotTheSameToken()
        external
        givenSendMsgIsCalledWithWrongParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should revert with Rebalancer_RequestNotValid
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setWhitelistedDestination(0, true);
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(usdc), message: "", bridgeData: ""});
        vm.expectRevert(IRebalancer.Rebalancer_RequestNotValid.selector);
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    modifier givenSendMsgIsCalledWithRightParameters() {
        roles.allowFor(address(this), roles.REBALANCER_EOA(), true);
        _;
    }

    function test_RevertWhen_MarketDoesNotHaveEnoughTokens()
        external
        givenSendMsgIsCalledWithRightParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
    {
        // it should revert
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: "", bridgeData: ""});
        vm.expectRevert();
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), 1 ether, _msg);
    }

    function test_WhenMarketHasEnoughTokensButTransferSizeIsNotMet(uint256 amount)
        external
        givenSendMsgIsCalledWithRightParameters
        givenSenderHasRoleGUARDIAN_BRIDGE
        inRange(amount, SMALL, LARGE)
    {
        rebalancer.setWhitelistedBridgeStatus(address(bridgeMock), true);
        rebalancer.setMaxTransferSize(0, address(weth), amount - 1);
        IRebalancer.Msg memory _msg =
            IRebalancer.Msg({dstChainId: 0, token: address(weth), message: abi.encode(amount), bridgeData: ""});
        _getTokens(weth, address(mWethHost), amount);
        vm.expectRevert();
        rebalancer.sendMsg(address(bridgeMock), address(mWethHost), amount, _msg);
    }
}
