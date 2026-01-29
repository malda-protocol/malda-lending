// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {
    CCTPBridgeIntegration as LegacyCCTPBridgeIntegration
} from "test/integration/bridges/CCTPBridge.Integration.t.sol";
import {
    EverclearBridgeV2Integration as LegacyEverclearBridgeV2Integration
} from "test/integration/bridges/EverclearBridgeV2.Integration.t.sol";
import {
    LZUnifiedBridgeIntegrationTest as LegacyLZUnifiedBridgeIntegrationTest
} from "test/integration/bridges/LZUnifiedBridge.t.sol";

contract CCTPBridgeIntegrationV2 is LegacyCCTPBridgeIntegration {}

contract EverclearBridgeV2IntegrationV2 is LegacyEverclearBridgeV2Integration {}

contract LZUnifiedBridgeIntegrationTestV2 is LegacyLZUnifiedBridgeIntegrationTest {}
