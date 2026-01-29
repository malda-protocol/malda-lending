// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {mTokenGateway_admin as LegacyMTokenGatewayAdmin} from "test/unit/mTokenGateway/mTokenGateway_admin.t.sol";
import {mTokenGateway_outHere as LegacyMTokenGatewayOutHere} from "test/unit/mTokenGateway/mTokenGateway_outHere.t.sol";
import {
    mTokenGateway_supplyOnHost as LegacyMTokenGatewaySupplyOnHost
} from "test/unit/mTokenGateway/mTokenGateway_supplyOnHost.t.sol";
import {
    mTokenGateway_liquidate as LegacyMTokenGatewayLiquidate
} from "test/unit/mTokenGateway/mTokenGateway_liquidate.t.sol";

contract MTokenGatewayAdminV2 is LegacyMTokenGatewayAdmin {}

contract MTokenGatewayOutHereV2 is LegacyMTokenGatewayOutHere {}

contract MTokenGatewaySupplyOnHostV2 is LegacyMTokenGatewaySupplyOnHost {}

contract MTokenGatewayLiquidateV2 is LegacyMTokenGatewayLiquidate {}
