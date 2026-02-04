// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {AccrossBridge} from "src/rebalancer/bridges/AcrossBridge.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {Roles} from "src/Roles.sol";

import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockAcrossSpokePool, MockMarket, MockRebalancer} from "test/v2/mocks/rebalancer/AcrossBridgeMocks.t.sol";
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract AcrossBridgeTest is BaseTest {
    Roles internal roles;
    AccrossBridge internal bridge;
    MockAcrossSpokePool internal spokePool;
    MockRebalancer internal rebalancer;
    ERC20Mock internal token;
    MockMarket internal market;

    function setUp() public override {
        super.setUp();

        roles = new Roles(address(this));
        spokePool = new MockAcrossSpokePool();
        rebalancer = new MockRebalancer();

        token = new ERC20Mock("Token", "TOK", 18, address(this), address(0), type(uint256).max);
        market = new MockMarket(address(token));

        bridge = new AccrossBridge(address(roles), address(spokePool), address(rebalancer));

        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), true);
        roles.allowFor(address(this), roles.REBALANCER(), true);
    }

    ////////////////////////////////////////////////////////////
    //                      constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_AcrossBridge_AddressNotValid_whenSpokePoolZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new AccrossBridge(address(roles), address(0), address(rebalancer));
    }

    function test_unit_constructor_revertsWith_AcrossBridge_AddressNotValid_whenRebalancerZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        new AccrossBridge(address(roles), address(spokePool), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                 setWhitelistedRelayer                  //
    ////////////////////////////////////////////////////////////

    function test_unit_setWhitelistedRelayer_revertsWith_BaseBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), false);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);
    }

    function test_unit_setWhitelistedRelayer_revertsWith_AcrossBridge_AddressNotValid() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, address(0), true);
    }

    function test_unit_setWhitelistedRelayer_success() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, true, true);
        emit AccrossBridge.WhitelistedRelayerStatusUpdated(address(this), MAINNET_CHAIN_ID, users.bob, true);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertTrue(
            bridge.isRelayerWhitelisted(MAINNET_CHAIN_ID, users.bob),
            "expected condition to be true: bridge.isRelayerWhitelisted(MAINNET_CHAIN_ID, users.bob)"
        );
    }

    ////////////////////////////////////////////////////////////
    //                 handleV3AcrossMessage                  //
    ////////////////////////////////////////////////////////////

    function test_unit_handleV3AcrossMessage_revertsWith_AcrossBridge_NotAuthorized() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_NotAuthorized.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(market)));
    }

    function test_unit_handleV3AcrossMessage_revertsWith_AcrossBridge_InvalidReceiver() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_InvalidReceiver.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(spokePool));
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(market)));
    }

    function test_unit_handleV3AcrossMessage_revertsWith_AcrossBridge_TokenMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        MockMarket otherMarket = new MockMarket(users.bob);
        rebalancer.setWhitelisted(address(otherMarket), true);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_TokenMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(spokePool));
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(otherMarket)));
    }

    function test_unit_handleV3AcrossMessage_success() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        rebalancer.setWhitelisted(address(market), true);
        token.mint(address(bridge), 5e18);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, false, false, true);
        emit AccrossBridge.Rebalanced(address(market), 5e18);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        vm.prank(address(spokePool));
        bridge.handleV3AcrossMessage(address(token), 5e18, address(0), abi.encode(address(market)));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(token.balanceOf(address(market)), 5e18, "expected token.balanceOf(address(market)) to equal 5e18");
    }

    ////////////////////////////////////////////////////////////
    //                         sendMsg                        //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory message = _encodeMessage(10, 10, users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(9, address(market), MAINNET_CHAIN_ID, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_AcrossBridge_RelayerNotValid() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bytes memory message = _encodeMessage(10, 10, users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_RelayerNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(10, address(market), MAINNET_CHAIN_ID, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_AcrossBridge_MaxFeeExceeded() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);
        bytes memory message = _encodeMessage(100, 80, users.bob);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_MaxFeeExceeded.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(100, address(market), MAINNET_CHAIN_ID, address(token), message, "");
    }

    function test_fuzz_sendMsg_success(uint256 inputAmount, uint256 outputAmount) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);

        inputAmount = bound(inputAmount, 1, 1e18);
        uint256 maxSlippage = (inputAmount * 1e4) / 1e5;
        uint256 minOutput = inputAmount - maxSlippage;
        outputAmount = bound(outputAmount, minOutput, inputAmount);
        bytes memory message = _encodeMessage(inputAmount, outputAmount, users.bob);

        token.mint(address(this), inputAmount);
        token.approve(address(bridge), inputAmount);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.sendMsg(inputAmount, address(market), MAINNET_CHAIN_ID, address(token), message, "");

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        assertEq(spokePool.lastDepositor(), address(this), "expected spokePool.lastDepositor() to equal address(this)");
        assertEq(
            spokePool.lastRecipient(), address(bridge), "expected spokePool.lastRecipient() to equal address(bridge)"
        );
        assertEq(
            spokePool.lastInputToken(), address(token), "expected spokePool.lastInputToken() to equal address(token)"
        );
        assertEq(
            spokePool.lastOutputToken(), address(token), "expected spokePool.lastOutputToken() to equal address(token)"
        );
        assertEq(spokePool.lastInputAmount(), inputAmount, "expected spokePool.lastInputAmount() to equal inputAmount");
        assertEq(
            spokePool.lastOutputAmount(), outputAmount, "expected spokePool.lastOutputAmount() to equal outputAmount"
        );
        assertEq(
            spokePool.lastDestinationChainId(),
            MAINNET_CHAIN_ID,
            "expected spokePool.lastDestinationChainId() to equal MAINNET_CHAIN_ID"
        );
        assertEq(
            spokePool.lastExclusiveRelayer(), users.bob, "expected spokePool.lastExclusiveRelayer() to equal users.bob"
        );
        assertEq(spokePool.lastFillDeadline(), 100, "expected spokePool.lastFillDeadline() to equal 100");
        assertEq(spokePool.lastExclusivityDeadline(), 200, "expected spokePool.lastExclusivityDeadline() to equal 200");
        assertEq(spokePool.lastMessageLength(), 32, "expected spokePool.lastMessageLength() to equal 32");
        assertEq(
            spokePool.lastMessageWord(),
            bytes32(uint256(uint160(address(market)))),
            "expected spokePool.lastMessageWord() to equal bytes32(uint256(uint160(address(market))))"
        );
    }

    ////////////////////////////////////////////////////////////
    //                          getFee                        //
    ////////////////////////////////////////////////////////////

    function test_unit_getFee_revertsWith_AcrossBridge_NotImplemented() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(AccrossBridge.AcrossBridge_NotImplemented.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        bridge.getFee(MAINNET_CHAIN_ID, "", "");
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _encodeMessage(uint256 inputAmount, uint256 outputAmount, address relayer)
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(address(token), inputAmount, outputAmount, relayer, uint32(100), uint32(200));
    }
}
