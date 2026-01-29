// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {
    BaseOftMessageExecutorTest as LegacyBaseOftMessageExecutorTest,
    rsEthOftMessageExecutorTest as LegacyRsEthOftMessageExecutorTest,
    weEthOftMessageExecutorTest as LegacyWeEthOftMessageExecutorTest
} from "test/unit/Rebalancer/OftMessageExecutor.t.sol";

contract BaseOftMessageExecutorTestV2 is LegacyBaseOftMessageExecutorTest {}

contract RsEthOftMessageExecutorTestV2 is LegacyRsEthOftMessageExecutorTest {}

contract WeEthOftMessageExecutorTestV2 is LegacyWeEthOftMessageExecutorTest {}
