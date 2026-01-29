// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {mToken_base as LegacyMTokenBase} from "test/unit/mToken/mToken_base.t.sol";
import {mTokenConfiguration_test as LegacyMTokenConfiguration} from "test/unit/mToken/mTokenConfiguration.t.sol";
import {mToken_liquidate as LegacyMTokenLiquidate} from "test/unit/mToken/mToken_liquidate.t.sol";

contract MTokenBaseV2 is LegacyMTokenBase {}

contract MTokenConfigurationV2 is LegacyMTokenConfiguration {}

contract MTokenLiquidateV2 is LegacyMTokenLiquidate {}
