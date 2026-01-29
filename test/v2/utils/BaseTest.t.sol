// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;
import {Helpers} from "test/v2/utils/Helpers.t.sol";
import {Users} from "test/v2/utils/Users.t.sol";

abstract contract BaseTest is Helpers {
    Users internal users;

    function setUp() public virtual {
        vm.warp(DEFAULT_START_TIME);
        vm.chainId(DEFAULT_CHAIN_ID);

        _initUsers();
        _fundUsers();
    }

    function _initUsers() internal {
        users = Users({
            admin: makeAddr("Admin"),
            alice: makeAddr("Alice"),
            bob: makeAddr("Bob"),
            carol: makeAddr("Carol"),
            guardian: makeAddr("Guardian"),
            pauser: makeAddr("Pauser"),
            feeReceiver: makeAddr("FeeReceiver")
        });
    }

    function _fundUsers() internal {
        vm.deal(users.admin, LARGE);
        vm.deal(users.alice, LARGE);
        vm.deal(users.bob, LARGE);
        vm.deal(users.carol, LARGE);
        vm.deal(users.guardian, LARGE);
        vm.deal(users.pauser, LARGE);
        vm.deal(users.feeReceiver, LARGE);
    }
}
