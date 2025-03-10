// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.8.28;

/*
 _____ _____ __    ____  _____ 
|     |  _  |  |  |    \|  _  |
| | | |     |  |__|  |  |     |
|_|_|_|__|__|_____|____/|__|__|   
*/

import {IRoles} from "src/interfaces/IRoles.sol";

abstract contract BaseBridge {
    // ----------- STORAGE ------------
    IRoles public roles;

    error BaseBridge_NotAuthorized();
    error BaseBridge_AmountMismatch();
    error BaseBridge_AmountNotValid();
    error BaseBridge_AddressNotValid();

    constructor(address _roles) {
        require(_roles != address(0), BaseBridge_AddressNotValid());

        roles = IRoles(_roles);
    }

    modifier onlyBridgeConfigurator() {
        if (!roles.isAllowedFor(msg.sender, roles.GUARDIAN_BRIDGE())) revert BaseBridge_NotAuthorized();
        _;
    }

    modifier onlyRebalancer() {
        if (!roles.isAllowedFor(msg.sender, roles.REBALANCER())) revert BaseBridge_NotAuthorized();
        _;
    }
}
