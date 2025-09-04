// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import "forge-std/Test.sol";

// ADJUST THIS PATH if your file is elsewhere:
import {LifiBridge, ILiFi, ILiFiLIFuel} from "src/rebalancer/bridges/LifiBridge.sol";

import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockRoles} from "test/mocks/MockRoles.sol";
import {MockLiFiDiamond} from "test/mocks/MockLiFiDiamond.sol";

contract LifiBridgeTest is Test {
    address internal rebalancer = address(0x123);
    address internal configurator = address(0x456);
    address internal stranger = address(0x789);

    MockRoles internal roles;
    MockLiFiDiamond internal diamond;
    LifiBridge internal bridge;
    MockERC20 internal token;

    function setUp() public {
        roles = new MockRoles();
        roles.setRebalancer(rebalancer, true);
        roles.setBridgeConfigurator(configurator, true);
        roles.setAllowed(configurator, true);
        roles.setAllowed(address(this), true);
        roles.setAllowed(rebalancer, true);

        diamond = new MockLiFiDiamond();
        bridge = new LifiBridge(address(roles), address(diamond));

        token = new MockERC20("Mock Token", "MOCK", 18);
    }

    // --- constructor ---

    function test_constructor_reverts_whenDiamondZero() public {
        vm.expectRevert(LifiBridge.LiFiBridge_AddressNotValid.selector);
        new LifiBridge(address(roles), address(0));
    }

    function test_constructor_setsDiamond_andDefaultAllowedSelectors() public {
        // diamond address
        assertEq(bridge.lifiDiamond(), address(diamond));

        // defaults: LI.Fuel two entry points are allowed
        bytes4 startSel = ILiFiLIFuel.startBridgeTokensViaLIFuel.selector;
        bytes4 swapSel  = ILiFiLIFuel.swapAndStartBridgeTokensViaLIFuel.selector;
        assertTrue(bridge.allowedSelectors(startSel));
        assertTrue(bridge.allowedSelectors(swapSel));
    }

    // --- admin: setAllowedSelector ---

    function test_onlyConfigurator_can_setAllowedSelector() public {
        bytes4 fakeSel = bytes4(keccak256("startBridgeTokensViaStargate((bytes32,string,string,address,address,address,uint256,uint256,bool,bool))"));

        // unauthorized
        vm.prank(stranger);
        vm.expectRevert(); // BaseBridge's onlyBridgeConfigurator() revert (unknown selector), accept any revert
        bridge.setAllowedSelector(fakeSel, true);

        // authorized
        vm.prank(configurator);
        bridge.setAllowedSelector(fakeSel, true);
        assertTrue(bridge.allowedSelectors(fakeSel));

        // flip back to false
        vm.prank(configurator);
        bridge.setAllowedSelector(fakeSel, false);
        assertFalse(bridge.allowedSelectors(fakeSel));
    }

    // --- getFee ---

    function test_getFee_alwaysReverts_NotImplemented() public view {
        // staticcall so we don't need to set msg.sender role
        // expecting custom error selector
        bytes memory data = abi.encodeWithSelector(LifiBridge.getFee.selector, uint32(1), bytes(""), bytes(""));
        (bool ok, bytes memory ret) = address(bridge).staticcall(data);
        require(!ok, "getFee should revert");
        // check custom error selector
        bytes4 sel;
        assembly { sel := mload(add(ret, 0x20)) }
        require(sel == LifiBridge.LiFiBridge_NotImplemented.selector, "wrong error");
    }

    // --- sendMsg (ERC20 path) ---

    function test_sendMsg_onlyRebalancer() public {
        vm.prank(stranger);
        vm.expectRevert(); // onlyRebalancer()
        bridge.sendMsg(1e18, address(0xABCD), 10, address(token), bytes(""), bytes(""));
    }

    function test_sendMsg_erc20_happyPath_callsLIFuel_withExactBridgeData_andTransfers() public {
        uint256 amount = 1_234_567_890_000_000_000; // 1.2345e18
        uint32 dstId = 10;
        address market = address(0xA11CE);

        // mint to rebalancer and approve bridge to pull
        token.mint(rebalancer, amount);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), type(uint256).max);

        // call
        bridge.sendMsg(amount, market, dstId, address(token), bytes(""), bytes(""));
        vm.stopPrank();

        // Diamond mock should have been called exactly once
        assertEq(diamond.called(), 1, "diamond not called exactly once");

        // The diamond mock pulls tokens via transferFrom(msg.sender = bridge)
        // Ensure balances reflect that:
        assertEq(token.balanceOf(address(bridge)), 0, "bridge should not retain tokens");
        assertEq(token.balanceOf(address(diamond)), amount, "diamond did not receive tokens");

        // Validate BridgeData content
        ILiFi.BridgeData memory bd = diamond.lastBridgeData();
        assertEq(address(bd.sendingAssetId), address(token), "sendingAssetId");
        assertEq(bd.receiver, market, "receiver");
        assertEq(bd.minAmount, amount, "minAmount");
        assertEq(bd.destinationChainId, uint256(dstId), "dst chain");
        assertFalse(bd.hasSourceSwaps, "hasSourceSwaps");
        assertFalse(bd.hasDestinationCall, "hasDestinationCall");

        // string equality via hash
        assertEq(keccak256(bytes(bd.bridge)), keccak256(bytes("LIFuel")), "bridge name");
        assertEq(keccak256(bytes(bd.integrator)), keccak256(bytes("Malda")), "integrator");

        // transactionId deterministic check (same formula as in contract)
        bytes32 expectedTxId = keccak256(
            abi.encode(
                block.chainid,
                address(bridge),
                market,
                address(token),
                amount,
                dstId,
                diamond.capturedTimestamp() // the mock records the block.timestamp seen in call
            )
        );
        assertEq(bd.transactionId, expectedTxId, "transactionId mismatch");

        // Ensure no ETH was sent on ERC20 path
        assertEq(diamond.lastMsgValue(), 0, "unexpected msg.value");
    }

    function test_sendMsg_withoutApproval_revertsOnTransferFrom() public {
        uint256 amount = 5e18;
        token.mint(rebalancer, amount);

        vm.prank(rebalancer);
        vm.expectRevert(); // SafeERC20 transferFrom -> revert due to no allowance
        bridge.sendMsg(amount, address(0xA11CE), 10, address(token), bytes(""), bytes(""));
    }

    function test_sendMsg_transactionIdDiffersAcrossCalls() public {
        uint256 amount = 7e17;
        uint32 dstId = 25;
        address market = address(0x135);

        // fund and approve for two calls
        token.mint(rebalancer, amount * 2);
        vm.startPrank(rebalancer);
        token.approve(address(bridge), type(uint256).max);

        // 1st call
        bridge.sendMsg(amount, market, dstId, address(token), bytes(""), bytes(""));
        ILiFi.BridgeData memory first = diamond.lastBridgeData();
        bytes32 txId1 = first.transactionId;

        // move time forward to ensure different txId (since timestamp is part of it)
        vm.warp(block.timestamp + 2);

        // 2nd call (same inputs)
        bridge.sendMsg(amount, market, dstId, address(token), bytes(""), bytes(""));
        ILiFi.BridgeData memory second = diamond.lastBridgeData();
        bytes32 txId2 = second.transactionId;

        vm.stopPrank();

        assertTrue(txId1 != txId2, "transactionId should differ across calls");
        assertEq(diamond.called(), 2, "diamond should be called twice");

        // diamond should hold the sum
        assertEq(token.balanceOf(address(diamond)), amount * 2, "diamond token balance mismatch");
    }
}
