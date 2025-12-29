// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";

interface IERC20 {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IFirewall {
    function addConsumers(address[] memory consumers) external;
}

contract FirewallIntegration is Test {
    uint256 internal baseFork;
    address internal ownerOnChain;

    mTokenGateway internal extensionMarket;

    address internal roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
    address internal blacklister = 0x46fF12FA621Df323a0C4e529d580e91222a5ad70;
    address internal zkVerifier = 0x24Fa38dadA9e772Bf3474C4d3d190c326744Be32;

    address internal baseChainUnderlying = 0x4200000000000000000000000000000000000006; // WETH

    address internal firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
    address internal firewallAdmin = 0x9ddf072ceF9622d84C2e3C60097eaAE3d6688c1f;

    function setUp() public {
        string memory baseRpc = vm.envString("BASE_RPC_URL");
        baseFork = vm.createSelectFork(baseRpc);

        mTokenGateway gatewayImpl = new mTokenGateway();
        bytes memory wethGatewayInitData = abi.encodeWithSelector(
            mTokenGateway.initialize.selector,
            payable(address(this)),
            baseChainUnderlying,
            roles,
            blacklister,
            zkVerifier
        );

        ERC1967Proxy wethGatewayProxy = new ERC1967Proxy(address(gatewayImpl), wethGatewayInitData);
        extensionMarket = mTokenGateway(address(wethGatewayProxy));
        vm.label(address(extensionMarket), "extensionMarket");
    }

    // forge test --mt test_mint_without_firewall --evm-version cancun
    // Need to run with `cancun` otherwise you may get `NotActivated`.
    function test_mint_without_firewall() external {
        uint256 amount = 1e17;

        deal(baseChainUnderlying, address(this), amount);

        uint256 balanceWethBefore = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInBefore = extensionMarket.accAmountIn(address(this));

        IERC20(baseChainUnderlying).approve(address(extensionMarket), amount);
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));

        uint256 balanceWethAfter = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInAfter = extensionMarket.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }

    function test_mint_with_firewall() external {
        vm.skip(true);

        uint256 amount = 1e17;

        vm.startPrank(firewallAdmin);
        address;
        consumers[0] = address(extensionMarket);
        IFirewall(firewall).addConsumers(consumers);
        vm.stopPrank();

        extensionMarket.initFirewall(firewall);
        extensionMarket.setIsStrictMode(false);

        deal(baseChainUnderlying, address(this), amount);

        uint256 balanceWethBefore = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInBefore = extensionMarket.accAmountIn(address(this));

        IERC20(baseChainUnderlying).approve(address(extensionMarket), amount);
        vm.expectRevert("Account not registered");
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));

        extensionMarket.firewallRegister(address(this));

        vm.warp(block.timestamp + 10 minutes);
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));

        uint256 balanceWethAfter = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInAfter = extensionMarket.accAmountIn(address(this));

        // it should decrease the caller underlying balance
        assertEq(balanceWethAfter + amount, balanceWethBefore);

        // it should increase accAmount
        assertGt(accAmountInAfter, accAmountInBefore);
    }
}
