// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";
import {MockRoles} from "test/v2/mocks/rebalancer/CCTPBridgeRolesMocks.t.sol";

contract CCTPBridgeForkTest is BaseForkTest {
    address internal constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant MAINNET_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address internal constant MAINNET_MSG_TRANSMITTER = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

    // cctp domains
    uint32 internal constant ETH_DOMAIN = 0;
    uint32 internal constant BASE_DOMAIN = 6;
    uint32 internal constant BASE_CHAIN_ID = 8453;

    MockRoles internal roles;
    CCTPBridge internal bridge;

    address internal rebalancer;

    function setUp() public override {
        super.setUp();
        _selectEthFork();

        roles = new MockRoles();
        rebalancer = address(this);

        roles.grantRebalancer(rebalancer);
        roles.grantBridgeConfigurator(address(this));
        roles.grantGuardianBridge(address(this));

        bridge = new CCTPBridge(address(roles), MAINNET_TOKEN_MESSENGER, MAINNET_MSG_TRANSMITTER, rebalancer);

        bridge.setAcceptedToken(MAINNET_USDC, true);
        bridge.setDomainMapping(uint32(block.chainid), ETH_DOMAIN);
        bridge.setDomainMapping(BASE_CHAIN_ID, BASE_DOMAIN);

        uint256 amount = 1_000e6;
        deal(MAINNET_USDC, rebalancer, amount);

        IERC20(MAINNET_USDC).approve(address(bridge), type(uint256).max);
    }

    ////////////////////////////////////////////////////////////
    //                        SendMsg                          //
    ////////////////////////////////////////////////////////////

    function test_forkSendMsg_success_mainnetUsdcBurns() public {
        uint256 amount = 100e6;

        uint256 balBeforeRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balBeforeBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));

        address fakeMarket = users.bob;

        // domain mappings already set in setUp, but OK to set again if you want
        bridge.setDomainMapping(uint32(block.chainid), ETH_DOMAIN);
        bridge.setDomainMapping(BASE_CHAIN_ID, BASE_DOMAIN);

        bridge.sendMsg(amount, fakeMarket, BASE_CHAIN_ID, MAINNET_USDC, "", "");

        uint256 balAfterRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balAfterBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));

        assertEq(balBeforeRebalancer - balAfterRebalancer, amount, "rebalancer delta");
        assertEq(balAfterBridge, balBeforeBridge, "bridge should not hold USDC after burn");
    }
}
