// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {BaseTest} from "./BaseTest.t.sol";

abstract contract BaseForkTest is BaseTest {
    uint256 internal lineaFork;
    uint256 internal ethFork;
    uint256 internal baseFork;

    string internal lineaUrl;
    string internal ethUrl;
    string internal baseUrl;

    function setUp() public virtual override {
        super.setUp();
        lineaUrl = vm.envString("LINEA_RPC_URL");
        ethUrl = vm.envString("MAINNET_RPC_URL");
        baseUrl = vm.envString("BASE_RPC_URL");

        lineaFork = vm.createSelectFork(lineaUrl);
        ethFork = vm.createSelectFork(ethUrl);
        baseFork = vm.createSelectFork(baseUrl);
    }

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
