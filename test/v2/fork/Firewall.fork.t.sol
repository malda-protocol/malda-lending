// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {BaseForkTest} from "test/v2/utils/BaseForkTest.t.sol";

interface IFirewall {
    function addConsumers(address[] memory consumers) external;
}

contract FirewallForkTest is BaseForkTest {
    mTokenGateway internal extensionMarket;

    address internal roles = 0xB97bB519743A5096505E4d3e6507a189Fa2B39f9;
    address internal blacklister = 0x46fF12FA621Df323a0C4e529d580e91222a5ad70;
    address internal zkVerifier = 0x24Fa38dadA9e772Bf3474C4d3d190c326744Be32;

    address internal baseChainUnderlying = 0x4200000000000000000000000000000000000006; // WETH

    address internal firewall = 0x4E7bbAA670A5E2CD9a170Eb4E1468517Ad2A1448;
    address internal firewallAdmin = 0x9ddf072ceF9622d84C2e3C60097eaAE3d6688c1f;

    function setUp() public override {
        super.setUp();
        _selectBaseFork();

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

    // forge test --mt test_fork_supplyOnHost_success --evm-version cancun
    // Need to run with `cancun` otherwise you may get `NotActivated`

    ////////////////////////////////////////////////////////////
    //                      SupplyOnHost                      //
    ////////////////////////////////////////////////////////////

    function test_fork_supplyOnHost_success() external {
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

    function test_fork_supplyOnHost_revertsWith_AccountNotRegistered() external {
        vm.skip(true);

        uint256 amount = 1e17;

        vm.startPrank(firewallAdmin);
        address[] memory consumers = new address[](1);
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
