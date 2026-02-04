// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseForkTest is BaseTest {
    uint256 internal lineaFork;
    uint256 internal ethFork;
    uint256 internal baseFork;

    uint256 internal constant _UNINITIALIZED_FORK = type(uint256).max;

    // Pinned blocks reduce RPC load and make fork tests more deterministic.
    // Individual test suites can still override by setting `lineaFork/baseFork/ethFork` directly.
    uint256 internal constant LINEA_FORK_BLOCK = 24_326_770;
    uint256 internal constant BASE_FORK_BLOCK = 41_673_000;
    uint256 internal constant MAINNET_FORK_BLOCK = 24_377_000;

    function setUp() public virtual override {
        super.setUp();

        // Fork IDs can be `0`, so we can't use `0` as an "unset" sentinel.
        lineaFork = _UNINITIALIZED_FORK;
        ethFork = _UNINITIALIZED_FORK;
        baseFork = _UNINITIALIZED_FORK;
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _selectLineaFork() internal {
        if (lineaFork == _UNINITIALIZED_FORK) {
            lineaFork = vm.createFork(vm.envString("LINEA_RPC_URL"), LINEA_FORK_BLOCK);
        }
        vm.selectFork(lineaFork);
        vm.chainId(uint256(LINEA_CHAIN_ID));
    }

    function _selectEthFork() internal {
        if (ethFork == _UNINITIALIZED_FORK) {
            ethFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), MAINNET_FORK_BLOCK);
        }
        vm.selectFork(ethFork);
        vm.chainId(1);
    }

    function _selectBaseFork() internal {
        if (baseFork == _UNINITIALIZED_FORK) {
            baseFork = vm.createFork(vm.envString("BASE_RPC_URL"), BASE_FORK_BLOCK);
        }
        vm.selectFork(baseFork);
        vm.chainId(8453);
    }

    function _fundErc20FromHolder(address token, address holder, address recipient, uint256 amount) internal {
        if (amount == 0) return;

        uint256 holderBalance = IERC20(token).balanceOf(holder);
        assertGe(holderBalance, amount, "token holder does not have enough balance for test funding");

        vm.prank(holder);
        bool ok = IERC20(token).transfer(recipient, amount);
        assertTrue(ok, "ERC20 transfer from holder failed");
    }

    function _fundEthFrom(address rich, address recipient, uint256 amount) internal {
        if (amount == 0) return;

        uint256 richBalance = rich.balance;
        assertGe(richBalance, amount, "rich account does not have enough ETH to fund");

        vm.prank(rich);
        (bool ok,) = payable(recipient).call{value: amount}("");
        assertTrue(ok, "ETH transfer funding failed");
    }

    function _selfFundEth(address rich, uint256 amount) internal {
        _fundEthFrom(rich, address(this), amount);
    }
}
