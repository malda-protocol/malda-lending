// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";

contract SmokeTest is BaseTest {
    function test_smoke_baseTest() public {
        assertTrue(users.alice != address(0));
        assertEq(block.chainid, DEFAULT_CHAIN_ID);
    }
}
