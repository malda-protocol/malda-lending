// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {CCTPBridge} from "src/rebalancer/bridges/CCTPBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockRoles {
    bytes32 public constant REBALANCER_ROLE = keccak256("REBALANCER_ROLE");
    bytes32 public constant BRIDGE_CONFIGURATOR_ROLE = keccak256("BRIDGE_CONFIGURATOR_ROLE");
    bytes32 public constant GUARDIAN_BRIDGE_ROLE = keccak256("GUARDIAN_BRIDGE_ROLE");

    mapping(address account => mapping(bytes32 role => bool allowed)) public perms;

    function grantRebalancer(address who) external {
        perms[who][REBALANCER_ROLE] = true;
    }

    function grantBridgeConfigurator(address who) external {
        perms[who][BRIDGE_CONFIGURATOR_ROLE] = true;
    }

    function grantGuardianBridge(address who) external {
        perms[who][GUARDIAN_BRIDGE_ROLE] = true;
    }

    // must match BaseBridge's Roles interface
    function REBALANCER() external pure returns (bytes32) {
        return REBALANCER_ROLE;
    }

    function GUARDIAN_BRIDGE() external pure returns (bytes32) {
        return GUARDIAN_BRIDGE_ROLE;
    }

    function BRIDGE_CONFIGURATOR() external pure returns (bytes32) {
        return BRIDGE_CONFIGURATOR_ROLE;
    }

    function isAllowedFor(address account, bytes32 role) external view returns (bool) {
        return perms[account][role];
    }
}

contract CCTPBridgeIntegration is Test {
    address internal constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant MAINNET_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address internal constant MAINNET_MSG_TRANSMITTER = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

    // cctp domains
    uint32 internal constant ETH_DOMAIN = 0;
    uint32 internal constant BASE_DOMAIN = 6;
    uint32 internal constant BASE_CHAINID = 8453;

    MockRoles internal roles;
    CCTPBridge internal bridge;

    address internal rebalancer;

    function setUp() public {
        string memory ethRpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(ethRpc);

        roles = new MockRoles();
        rebalancer = address(this);

        roles.grantRebalancer(rebalancer);
        roles.grantBridgeConfigurator(address(this));
        roles.grantGuardianBridge(address(this));

        bridge = new CCTPBridge(address(roles), MAINNET_TOKEN_MESSENGER, MAINNET_MSG_TRANSMITTER, rebalancer);

        bridge.setAcceptedToken(MAINNET_USDC, true);
        bridge.setDomainMapping(uint32(block.chainid), ETH_DOMAIN);
        bridge.setDomainMapping(BASE_CHAINID, BASE_DOMAIN);

        uint256 amount = 1_000e6;
        deal(MAINNET_USDC, rebalancer, amount);

        IERC20(MAINNET_USDC).approve(address(bridge), type(uint256).max);
    }

    function test_mainnetFork_sendMsg_USDC_burns() public {
        uint256 amount = 100e6;

        uint256 balBeforeRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balBeforeBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));

        address fakeMarket = address(0xCAFE);

        // domain mappings already set in setUp, but OK to set again if you want
        bridge.setDomainMapping(uint32(block.chainid), ETH_DOMAIN);
        bridge.setDomainMapping(BASE_CHAINID, BASE_DOMAIN);

        bridge.sendMsg(amount, fakeMarket, BASE_CHAINID, MAINNET_USDC, "", "");

        uint256 balAfterRebalancer = IERC20(MAINNET_USDC).balanceOf(rebalancer);
        uint256 balAfterBridge = IERC20(MAINNET_USDC).balanceOf(address(bridge));

        assertEq(balBeforeRebalancer - balAfterRebalancer, amount, "rebalancer delta");
        assertEq(balAfterBridge, balBeforeBridge, "bridge should not hold USDC after burn");
    }
}
