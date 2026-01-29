// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {BaseTest} from "test/v2/utils/BaseTest.t.sol";
import {BaseProtocolTest} from "test/v2/utils/BaseProtocolTest.t.sol";
import {BaseMTokenTest} from "test/v2/utils/BaseMTokenTest.t.sol";
import {BaseBatchSubmitterTest} from "test/v2/utils/BaseBatchSubmitterTest.t.sol";
import {BasePauserTest} from "test/v2/utils/BasePauserTest.t.sol";
import {BaseRebalancerTest} from "test/v2/utils/BaseRebalancerTest.t.sol";

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

contract MTokenSmokeTest is BaseMTokenTest {
    function test_smoke_mtoken() public {
        assertTrue(address(mWethHost) != address(0));
    }
}

contract BatchSubmitterSmokeTest is BaseBatchSubmitterTest {
    function test_smoke_batchSubmitter() public {
        assertTrue(address(batchSubmitter) != address(0));
    }
}

contract PauserSmokeTest is BasePauserTest {
    function test_smoke_pauser() public {
        assertTrue(address(pauser) != address(0));
    }
}

contract RebalancerSmokeTest is BaseRebalancerTest {
    function test_smoke_rebalancer() public {
        assertTrue(address(rebalancer) != address(0));
    }
}
