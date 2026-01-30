// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

import {Roles} from "src/Roles.sol";
import {AccrossBridge} from "src/rebalancer/bridges/AcrossBridge.sol";
import {BaseBridge} from "src/rebalancer/bridges/BaseBridge.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockAcrossSpokePool, MockMarket, MockRebalancer} from "test/v2/mocks/rebalancer/AcrossBridgeMocks.t.sol";

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

    function _encodeMessage(uint256 inputAmount, uint256 outputAmount, address relayer)
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(address(token), inputAmount, outputAmount, relayer, uint32(100), uint32(200));
    }

    ////////////////////////////////////////////////////////////
    //                      Constructor                       //
    ////////////////////////////////////////////////////////////

    function test_unit_constructor_revertsWith_AcrossBridge_AddressNotValid_variant2() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);
        new AccrossBridge(address(roles), address(0), address(rebalancer));
    }

    function test_unit_constructor_revertsWith_AcrossBridge_AddressNotValid() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);
        new AccrossBridge(address(roles), address(spokePool), address(0));
    }

    ////////////////////////////////////////////////////////////
    //                 SetWhitelistedRelayer                  //
    ////////////////////////////////////////////////////////////

    function test_unit_setWhitelistedRelayer_revertsWith_BaseBridge_NotAuthorized() external {
        roles.allowFor(address(this), roles.GUARDIAN_BRIDGE(), false);
        vm.expectRevert(BaseBridge.BaseBridge_NotAuthorized.selector);
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);
    }

    function test_unit_setWhitelistedRelayer_revertsWith_AcrossBridge_AddressNotValid() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_AddressNotValid.selector);
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, address(0), true);
    }

    function test_unit_setWhitelistedRelayer_success_updatesMapping() external {
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);
        assertTrue(bridge.isRelayerWhitelisted(1, users.bob));
    }

    ////////////////////////////////////////////////////////////
    //                 HandleV3AcrossMessage                  //
    ////////////////////////////////////////////////////////////

    function test_unit_handleV3AcrossMessage_revertsWith_AcrossBridge_NotAuthorized() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_NotAuthorized.selector);
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(market)));
    }

    function test_unit_handleV3AcrossMessage_revertsWith_AcrossBridge_InvalidReceiver() external {
        vm.prank(address(spokePool));
        vm.expectRevert(AccrossBridge.AcrossBridge_InvalidReceiver.selector);
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(market)));
    }

    function test_unit_handleV3AcrossMessage_revertsWith_AcrossBridge_TokenMismatch() external {
        MockMarket otherMarket = new MockMarket(users.bob);
        rebalancer.setWhitelisted(address(otherMarket), true);

        vm.prank(address(spokePool));
        vm.expectRevert(AccrossBridge.AcrossBridge_TokenMismatch.selector);
        bridge.handleV3AcrossMessage(address(token), 1, address(0), abi.encode(address(otherMarket)));
    }

    function test_unit_handleV3AcrossMessage_success_transfersToMarket() external {
        rebalancer.setWhitelisted(address(market), true);
        token.mint(address(bridge), 5e18);

        vm.prank(address(spokePool));
        bridge.handleV3AcrossMessage(address(token), 5e18, address(0), abi.encode(address(market)));

        assertEq(token.balanceOf(address(market)), 5e18);
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                         //
    ////////////////////////////////////////////////////////////

    function test_unit_sendMsg_revertsWith_BaseBridge_AmountMismatch() external {
        bytes memory message = _encodeMessage(10, 10, users.bob);

        vm.expectRevert(BaseBridge.BaseBridge_AmountMismatch.selector);
        bridge.sendMsg(9, address(market), MAINNET_CHAIN_ID, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_AcrossBridge_RelayerNotValid() external {
        bytes memory message = _encodeMessage(10, 10, users.bob);

        vm.expectRevert(AccrossBridge.AcrossBridge_RelayerNotValid.selector);
        bridge.sendMsg(10, address(market), MAINNET_CHAIN_ID, address(token), message, "");
    }

    function test_unit_sendMsg_revertsWith_AcrossBridge_MaxFeeExceeded() external {
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);
        bytes memory message = _encodeMessage(100, 80, users.bob);

        vm.expectRevert(AccrossBridge.AcrossBridge_MaxFeeExceeded.selector);
        bridge.sendMsg(100, address(market), MAINNET_CHAIN_ID, address(token), message, "");
    }

    function test_unit_sendMsg_success_transfersAndDeposits() external {
        bridge.setWhitelistedRelayer(MAINNET_CHAIN_ID, users.bob, true);

        uint256 inputAmount = 100;
        uint256 outputAmount = 95;
        bytes memory message = _encodeMessage(inputAmount, outputAmount, users.bob);

        token.mint(address(this), inputAmount);
        token.approve(address(bridge), inputAmount);

        bridge.sendMsg(inputAmount, address(market), MAINNET_CHAIN_ID, address(token), message, "");

        assertEq(spokePool.lastDepositor(), address(this));
        assertEq(spokePool.lastRecipient(), address(bridge));
        assertEq(spokePool.lastInputToken(), address(token));
        assertEq(spokePool.lastOutputToken(), address(token));
        assertEq(spokePool.lastInputAmount(), inputAmount);
        assertEq(spokePool.lastOutputAmount(), outputAmount);
        assertEq(spokePool.lastDestinationChainId(), MAINNET_CHAIN_ID);
        assertEq(spokePool.lastExclusiveRelayer(), users.bob);
        assertEq(spokePool.lastFillDeadline(), 100);
        assertEq(spokePool.lastExclusivityDeadline(), 200);
        assertEq(spokePool.lastMessageLength(), 32);
        assertEq(spokePool.lastMessageWord(), bytes32(uint256(uint160(address(market)))));
    }

    ////////////////////////////////////////////////////////////
    //                         GetFee                         //
    ////////////////////////////////////////////////////////////

    function test_unit_getFee_revertsWith_AcrossBridge_NotImplemented() external {
        vm.expectRevert(AccrossBridge.AcrossBridge_NotImplemented.selector);
        bridge.getFee(MAINNET_CHAIN_ID, "", "");
    }
}
