// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {mTokenGateway} from "src/mToken/extension/mTokenGateway.sol";
import {ImTokenGateway} from "src/interfaces/ImTokenGateway.sol";
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
    address internal constant BASE_WETH_HOLDER = 0x0392B12a1cEb0cd13af5Ea448CF5586EA609852D;

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
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 1e17;

        _fundErc20FromHolder(baseChainUnderlying, BASE_WETH_HOLDER, address(this), amount);
        IERC20(baseChainUnderlying).approve(address(extensionMarket), amount);

        uint256 balanceWethBefore = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInBefore = extensionMarket.accAmountIn(address(this));

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, false, address(extensionMarket));
        emit ImTokenGateway.mTokenGateway_Supplied(
            address(this), address(this), 0, 0, amount, uint32(block.chainid), uint32(59_144), bytes4("")
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceWethAfter = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInAfter = extensionMarket.accAmountIn(address(this));

        assertEq(
            balanceWethAfter + amount, balanceWethBefore, "caller WETH balance did not decrease by the supplied amount"
        );
        assertGt(accAmountInAfter, accAmountInBefore, "accAmountIn did not increase after supplying on host");
    }

    function test_fork_fuzz_supplyOnHost_success(uint256 amountRaw) external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = bound(amountRaw, 1, 2e17);

        _fundErc20FromHolder(baseChainUnderlying, BASE_WETH_HOLDER, address(this), amount);
        IERC20(baseChainUnderlying).approve(address(extensionMarket), amount);

        uint256 balanceWethBefore = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInBefore = extensionMarket.accAmountIn(address(this));
        uint256 expectedAccAmountIn = accAmountInBefore + amount;

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectEmit(true, true, false, false, address(extensionMarket));
        emit ImTokenGateway.mTokenGateway_Supplied(
            address(this), address(this), 0, 0, amount, uint32(block.chainid), uint32(59_144), bytes4("")
        );

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceWethAfter = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInAfter = extensionMarket.accAmountIn(address(this));

        assertEq(balanceWethAfter + amount, balanceWethBefore, "fuzz: caller balance should decrease by amount");
        assertEq(accAmountInAfter, expectedAccAmountIn, "fuzz: accAmountIn value mismatch");
    }

    function test_fork_supplyOnHost_revertsWith_AccountNotRegistered() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 1e17;

        vm.startPrank(firewallAdmin);
        address[] memory consumers = new address[](1);
        consumers[0] = address(extensionMarket);
        IFirewall(firewall).addConsumers(consumers);
        vm.stopPrank();

        extensionMarket.initFirewall(firewall);
        extensionMarket.setIsStrictMode(false);

        _fundErc20FromHolder(baseChainUnderlying, BASE_WETH_HOLDER, address(this), amount);
        IERC20(baseChainUnderlying).approve(address(extensionMarket), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert("Account not registered");

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));
    }

    function test_fork_supplyOnHost_success_whenAccountRegistered() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        uint256 amount = 1e17;

        vm.startPrank(firewallAdmin);
        address[] memory consumers = new address[](1);
        consumers[0] = address(extensionMarket);
        IFirewall(firewall).addConsumers(consumers);
        vm.stopPrank();

        extensionMarket.initFirewall(firewall);
        extensionMarket.setIsStrictMode(false);

        extensionMarket.firewallRegister(address(this));
        vm.warp(block.timestamp + 10 minutes);

        _fundErc20FromHolder(baseChainUnderlying, BASE_WETH_HOLDER, address(this), amount);
        IERC20(baseChainUnderlying).approve(address(extensionMarket), amount);

        uint256 balanceWethBefore = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInBefore = extensionMarket.accAmountIn(address(this));

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));

        // ~~~~~~~~~~ Assertions ~~~~~~~~~~
        uint256 balanceWethAfter = IERC20(baseChainUnderlying).balanceOf(address(this));
        uint256 accAmountInAfter = extensionMarket.accAmountIn(address(this));

        assertEq(
            balanceWethAfter + amount, balanceWethBefore, "caller WETH balance did not decrease by the supplied amount"
        );
        assertGt(accAmountInAfter, accAmountInBefore, "accAmountIn did not increase after supplying on host");
    }

    function test_fork_supplyOnHost_revertsWith_AmountNotValid_whenAmountZero() external {
        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_AmountNotValid.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        extensionMarket.supplyOnHost(0, address(this), bytes4(""));
    }

    function test_fork_supplyOnHost_revertsWith_NotEnoughGasFee() external {
        // ~~~~~~~~~~ Setup ~~~~~~~~~~
        extensionMarket.setGasFee(1);

        uint256 amount = 1e17;
        _fundErc20FromHolder(baseChainUnderlying, BASE_WETH_HOLDER, address(this), amount);
        IERC20(baseChainUnderlying).approve(address(extensionMarket), amount);

        // ~~~~~~~~~~ Expectations ~~~~~~~~~~
        vm.expectRevert(ImTokenGateway.mTokenGateway_NotEnoughGasFee.selector);

        // ~~~~~~~~~~ Call ~~~~~~~~~~
        extensionMarket.supplyOnHost(amount, address(this), bytes4(""));
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////
}
