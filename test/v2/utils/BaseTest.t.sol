// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {Helpers} from "./Helpers.t.sol";
import {Users} from "./Users.t.sol";

abstract contract BaseTest is Helpers {
    Users internal users;

    function setUp() public virtual {
        vm.warp(DEFAULT_START_TIME);
        vm.chainId(DEFAULT_CHAIN_ID);

        users = Users({
            admin: makeAddr("Admin"),
            alice: makeAddr("Alice"),
            bob: makeAddr("Bob"),
            carol: makeAddr("Carol"),
            guardian: makeAddr("Guardian"),
            pauser: makeAddr("Pauser"),
            feeReceiver: makeAddr("FeeReceiver")
        });

        vm.deal(users.admin, LARGE);
        vm.deal(users.alice, LARGE);
        vm.deal(users.bob, LARGE);
        vm.deal(users.carol, LARGE);
        vm.deal(users.guardian, LARGE);
        vm.deal(users.pauser, LARGE);
        vm.deal(users.feeReceiver, LARGE);
    }
}
