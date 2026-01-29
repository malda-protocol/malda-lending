// SPDX-License-Identifier: BSL-1.1
pragma solidity =0.8.28;

import {CommonLibTest as LegacyCommonLibTest} from "test/unit/libraries/CommonLib.t.sol";
import {
    HypernativeFirewallProtectedTest as LegacyHypernativeFirewallProtectedTest
} from "test/unit/libraries/HypernativeFirewallProtected.t.sol";
import {LZOptionsTest as LegacyLZOptionsTest} from "test/unit/libraries/LZOptions.t.sol";
import {SafeApproveTest as LegacySafeApproveTest} from "test/unit/libraries/SafeApprove.t.sol";
import {
    mTokenProofDecoderLibTest as LegacyMTokenProofDecoderLibTest
} from "test/unit/libraries/mTokenProofDecoderLib.t.sol";

contract CommonLibTestV2 is LegacyCommonLibTest {}

contract HypernativeFirewallProtectedTestV2 is LegacyHypernativeFirewallProtectedTest {}

contract LZOptionsTestV2 is LegacyLZOptionsTest {}

contract SafeApproveTestV2 is LegacySafeApproveTest {}

contract MTokenProofDecoderLibTestV2 is LegacyMTokenProofDecoderLibTest {}
