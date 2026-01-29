// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {BaseProtocolTest} from "test/v2/utils/BaseProtocolTest.t.sol";

contract SmokeTest is BaseTest {
    function test_smoke_baseTest() public {
        assertTrue(users.alice != address(0));
        assertEq(block.chainid, DEFAULT_CHAIN_ID);
    }
}

contract ProtocolSmokeTest is BaseProtocolTest {
    function test_smoke_protocol() public {
        assertTrue(address(operator) != address(0));
        assertTrue(address(roles) != address(0));
        assertTrue(address(blacklister) != address(0));
    }
}
