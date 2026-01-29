// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {ChainlinkOracleTest as LegacyChainlinkOracleTest} from "test/unit/oracle/ChainlinkOracle.t.sol";
import {DefaultGasHelperTest as LegacyDefaultGasHelperTest} from "test/unit/oracle/DefaultGasHelper.t.sol";
import {
    MixedPriceOracleV3AdminTest as LegacyMixedPriceOracleV3AdminTest
} from "test/unit/oracle/MixedPriceOracleV3_Admin.t.sol";
import {MixedPriceOracleV4Test as LegacyMixedPriceOracleV4Test} from "test/unit/oracle/MixedPriceOracleV4.t.sol";
import {MixedPriceOracleV3_Test as LegacyMixedPriceOracleV3Test} from "test/unit/oracle/OracleUnderlying.t.sol";

contract ChainlinkOracleTestV2 is LegacyChainlinkOracleTest {}

contract DefaultGasHelperTestV2 is LegacyDefaultGasHelperTest {}

contract MixedPriceOracleV3AdminTestV2 is LegacyMixedPriceOracleV3AdminTest {}

contract MixedPriceOracleV4TestV2 is LegacyMixedPriceOracleV4Test {}

contract MixedPriceOracleV3TestV2 is LegacyMixedPriceOracleV3Test {}
