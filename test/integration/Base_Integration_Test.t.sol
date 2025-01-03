// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|                           
*/

//contracts
import {Roles} from "src/Roles.sol";

import {Types} from "../utils/Types.sol";
import {Events} from "../utils/Events.sol";
import {Helpers} from "../utils/Helpers.sol";

abstract contract Base_Integration_Test is Events, Helpers, Types {
    // ----------- FORKS ------------
    uint256 public mainnetFork;
    uint256 public arbitrumFork;
    string public mainnetUrl = vm.envString("ETHEREUM_RPC_URL");
    string public arbitrumUrl = vm.envString("ARBITRUM_RPC_URL");

    // ----------- MALDA ------------
    Roles public roles;

    function setUp() public virtual {
        mainnetFork = vm.createSelectFork(mainnetUrl);
        arbitrumFork = vm.createSelectFork(arbitrumUrl);

        roles = new Roles(address(this));
        vm.label(address(roles), "Roles");
    }
}
