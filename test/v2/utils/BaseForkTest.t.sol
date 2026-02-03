// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

abstract contract BaseForkTest is BaseTest {
    uint256 internal lineaFork;
    uint256 internal ethFork;
    uint256 internal baseFork;

    function setUp() public virtual override {
        super.setUp();

        lineaFork = vm.createSelectFork(vm.envString("LINEA_RPC_URL"));
        ethFork = vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        baseFork = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    ////////////////////////////////////////////////////////////
    //                        Helpers                         //
    ////////////////////////////////////////////////////////////

    function _selectLineaFork() internal {
        vm.selectFork(lineaFork);
    }

    function _selectEthFork() internal {
        vm.selectFork(ethFork);
    }

    function _selectBaseFork() internal {
        vm.selectFork(baseFork);
    }
}
